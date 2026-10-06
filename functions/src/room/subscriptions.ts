/**
 * Resource Room subscriptions (Razorpay Subscriptions, auto-renew).
 *
 *  createRoomSubscription({ planKey })   → Razorpay subscription to approve
 *  verifyRoomSubscription({ subscriptionId, paymentId, signature })
 *                                         → first charge confirmed, Room opens
 *  cancelRoomSubscription()               → no more charges; access lasts
 *                                           until the paid period ends
 *  setRoomPlanPrice({ planKey, price })   → admin: new Razorpay plan
 *
 * Every later monthly / 3-monthly / 6-monthly charge arrives through the
 * razorpayWebhook (subscription.charged) → [applyCharge].
 */
import "../config";
import {
  FieldValue,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {
  type CallableRequest,
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  addMonths,
  Collections,
  CURRENCY_INR,
  OrderFields,
  OrderStatus,
  OrderType,
  ROOM_PLANS_DOC,
  RoomPlanDefaults,
  type RoomPlanKey,
  StatsFields,
  SubscriptionFields,
} from "../config";
import { refreshRoomAccess, toMillis } from "../access/access";
import { requireAdmin } from "../admin/require_admin";
import {
  isValidSubscriptionSignature,
  RAZORPAY_KEY_ID,
  RAZORPAY_KEY_SECRET,
  type RazorpayKeys,
  razorpaySubscriptionApi,
  type SubscriptionApi,
} from "../payments/razorpay";
import { hitRateLimit } from "../payments/rate_limit";
import { bumpDaily, bumpGlobal } from "../stats/stats";

export interface RoomDeps {
  keys: () => RazorpayKeys;
  api: SubscriptionApi;
}

const realDeps: RoomDeps = {
  keys: () => ({
    keyId: RAZORPAY_KEY_ID.value(),
    keySecret: RAZORPAY_KEY_SECRET.value(),
  }),
  api: razorpaySubscriptionApi,
};
const withKeys = {
  invoker: "public" as const,
  secrets: [RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET],
};

/** Statuses in which a subscription still renews (or is being set up). */
const LIVE = new Set(["authenticated", "active", "pending"]);

/** Charges Razorpay makes before stopping (~10 years). */
const totalCount = (months: number) => Math.ceil(120 / months);

const planName = (months: number) =>
  `PrepNotes Resource Room · ${months} month${months > 1 ? "s" : ""}`;

const planKeyOf = (v: unknown): RoomPlanKey => {
  if (typeof v === "string" && v in RoomPlanDefaults) return v as RoomPlanKey;
  throw new HttpsError("invalid-argument", "Unknown plan.");
};

const subsRef = () => getFirestore().collection(Collections.subscriptions);

interface StoredPlan {
  months: number;
  price: number;
  razorpayPlanId?: string;
}

/** The plan's current price + Razorpay plan id (creates the plan if needed). */
async function ensurePlan(
  key: RoomPlanKey,
  deps: RoomDeps,
): Promise<Required<StoredPlan>> {
  const ref = getFirestore().doc(ROOM_PLANS_DOC);
  const stored = ((await ref.get()).get(key) as StoredPlan | undefined) ?? {
    ...RoomPlanDefaults[key],
  };
  if (stored.razorpayPlanId) return stored as Required<StoredPlan>;
  const plan = await deps.api.createPlan(
    { months: stored.months, amount: stored.price, name: planName(stored.months) },
    deps.keys(),
  );
  const full = { ...stored, razorpayPlanId: plan.id };
  await ref.set({ [key]: full }, { merge: true });
  return full;
}

/** The user's subscription that still renews, if any. */
async function liveSubscription(uid: string) {
  const subs = await subsRef().where(SubscriptionFields.userId, "==", uid).get();
  return subs.docs.find((d) => LIVE.has(d.get(SubscriptionFields.status)));
}

export function makeCreateRoomSubscription(deps: RoomDeps) {
  return async (request: CallableRequest<unknown>) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in.");
    const uid = request.auth.uid;
    const key = planKeyOf((request.data as { planKey?: unknown } | null)?.planKey);
    await hitRateLimit(uid, "createOrder");
    if (await liveSubscription(uid)) {
      throw new HttpsError("already-exists", "already-subscribed");
    }

    let plan: Required<StoredPlan>;
    let sub: { id: string };
    try {
      plan = await ensurePlan(key, deps);
      sub = await deps.api.createSubscription(
        {
          planId: plan.razorpayPlanId,
          totalCount: totalCount(plan.months),
          notes: { uid, planKey: key },
        },
        deps.keys(),
      );
    } catch (e) {
      logger.error("Razorpay subscription failed", { uid, key, error: `${e}` });
      throw new HttpsError("unavailable", "Payment service is busy. Try again.");
    }
    await subsRef().doc(sub.id).set({
      [SubscriptionFields.userId]: uid,
      [SubscriptionFields.planKey]: key,
      [SubscriptionFields.razorpayPlanId]: plan.razorpayPlanId,
      [SubscriptionFields.amount]: plan.price,
      [SubscriptionFields.status]: "created",
      [SubscriptionFields.cancelAtPeriodEnd]: false,
      [SubscriptionFields.createdAt]: FieldValue.serverTimestamp(),
      [SubscriptionFields.updatedAt]: FieldValue.serverTimestamp(),
    });
    return {
      subscriptionId: sub.id,
      amount: plan.price,
      currency: CURRENCY_INR,
      keyId: deps.keys().keyId,
      months: plan.months,
      email: (request.auth.token.email as string | undefined) ?? "",
    };
  };
}

/**
 * Records one paid charge of a subscription (idempotent per payment):
 * an orders/{paymentId} row for history + stats, and the paid-until date.
 * [currentEndMs] = Razorpay's current_end; if unknown, now + plan months.
 */
export async function applyCharge(
  subscriptionId: string,
  paymentId: string,
  amount: number,
  currentEndMs?: number,
  now = new Date(),
): Promise<"charged" | "duplicate" | "not-found" | "amount-mismatch"> {
  const db = getFirestore();
  const subRef = subsRef().doc(subscriptionId);
  const orderRef = db.collection(Collections.orders).doc(paymentId);
  let uid = "";
  const out = await db.runTransaction(async (tx) => {
    const [sub, order] = await Promise.all([tx.get(subRef), tx.get(orderRef)]);
    if (!sub.exists) return "not-found" as const;
    if (amount !== sub.get(SubscriptionFields.amount)) {
      return "amount-mismatch" as const;
    }
    uid = sub.get(SubscriptionFields.userId) as string;
    const key = sub.get(SubscriptionFields.planKey) as RoomPlanKey;
    const months = RoomPlanDefaults[key]?.months ?? 1;
    const end = Math.max(
      toMillis(sub.get(SubscriptionFields.currentEnd)),
      currentEndMs ?? addMonths(now, months).getTime(),
    );
    tx.update(subRef, {
      [SubscriptionFields.status]: "active",
      [SubscriptionFields.currentEnd]: Timestamp.fromMillis(end),
      [SubscriptionFields.updatedAt]: FieldValue.serverTimestamp(),
    });
    if (order.exists) return "duplicate" as const;
    tx.set(orderRef, {
      [OrderFields.userId]: uid,
      [OrderFields.type]: OrderType.subscription,
      [OrderFields.planKey]: key,
      [OrderFields.subscriptionId]: subscriptionId,
      [OrderFields.noteIds]: [],
      [OrderFields.noteTitles]: [planName(months)],
      [OrderFields.amount]: amount,
      [OrderFields.currency]: CURRENCY_INR,
      [OrderFields.status]: OrderStatus.paid,
      [OrderFields.razorpayPaymentId]: paymentId,
      [OrderFields.createdAt]: FieldValue.serverTimestamp(),
      [OrderFields.paidAt]: FieldValue.serverTimestamp(),
    });
    bumpGlobal(tx, {
      [StatsFields.totalPurchases]: 1,
      [StatsFields.totalRevenue]: amount,
    });
    bumpDaily(tx, { purchases: 1, revenue: amount });
    return "charged" as const;
  });
  if (uid) await refreshRoomAccess(uid);
  logger.info("Room subscription charge", { subscriptionId, paymentId, out });
  return out;
}

/** Status change from Razorpay (halted, cancelled, completed, …). */
export async function setSubscriptionStatus(
  subscriptionId: string,
  status: string,
  currentEndMs?: number,
): Promise<boolean> {
  const ref = subsRef().doc(subscriptionId);
  const sub = await ref.get();
  if (!sub.exists) return false;
  const changes: Record<string, unknown> = {
    [SubscriptionFields.status]: status,
    [SubscriptionFields.updatedAt]: FieldValue.serverTimestamp(),
  };
  if (status === "cancelled") changes[SubscriptionFields.cancelAtPeriodEnd] = true;
  if (currentEndMs && currentEndMs > toMillis(sub.get(SubscriptionFields.currentEnd))) {
    changes[SubscriptionFields.currentEnd] = Timestamp.fromMillis(currentEndMs);
  }
  await ref.update(changes);
  await refreshRoomAccess(sub.get(SubscriptionFields.userId) as string);
  return true;
}

export function makeVerifyRoomSubscription(keySecret: () => string) {
  return async (request: CallableRequest<unknown>) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in.");
    const d = (request.data ?? {}) as Record<string, unknown>;
    const ok = (v: unknown): v is string =>
      typeof v === "string" && /^[\w-]{1,100}$/.test(v);
    if (!ok(d.subscriptionId) || !ok(d.paymentId) || typeof d.signature !== "string") {
      throw new HttpsError("invalid-argument", "Invalid payment details.");
    }
    const sub = await subsRef().doc(d.subscriptionId).get();
    if (!sub.exists || sub.get(SubscriptionFields.userId) !== request.auth.uid) {
      throw new HttpsError("not-found", "Subscription not found.");
    }
    if (!isValidSubscriptionSignature(d.subscriptionId, d.paymentId, d.signature, keySecret())) {
      logger.warn("Bad subscription signature", { sub: d.subscriptionId });
      throw new HttpsError("permission-denied", "Payment could not be verified.");
    }
    const out = await applyCharge(
      d.subscriptionId,
      d.paymentId,
      sub.get(SubscriptionFields.amount) as number,
    );
    if (out === "not-found" || out === "amount-mismatch") {
      throw new HttpsError("internal", "Payment could not be completed.");
    }
    return { active: true };
  };
}

export function makeCancelRoomSubscription(deps: RoomDeps) {
  return async (request: CallableRequest<unknown>) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Please sign in.");
    const live = await liveSubscription(request.auth.uid);
    if (!live) throw new HttpsError("not-found", "No active subscription.");
    try {
      await deps.api.cancelSubscription(live.id, true, deps.keys());
    } catch (e) {
      logger.error("Razorpay cancel failed", { sub: live.id, error: `${e}` });
      throw new HttpsError("unavailable", "Payment service is busy. Try again.");
    }
    await live.ref.update({
      [SubscriptionFields.cancelAtPeriodEnd]: true,
      [SubscriptionFields.updatedAt]: FieldValue.serverTimestamp(),
    });
    return { cancelled: true, accessUntil: toMillis(live.get(SubscriptionFields.currentEnd)) };
  };
}

export function makeSetRoomPlanPrice(deps: RoomDeps) {
  return async (request: CallableRequest<unknown>) => {
    requireAdmin(request);
    const d = (request.data ?? {}) as Record<string, unknown>;
    const key = planKeyOf(d.planKey);
    const price = d.price;
    if (typeof price !== "number" || !Number.isInteger(price) || price < 100 || price > 10_000_000) {
      throw new HttpsError("invalid-argument", "Price must be ₹1 – ₹1,00,000.");
    }
    const months = RoomPlanDefaults[key].months;
    let plan: { id: string };
    try {
      // Razorpay plans can't be edited: a new price = a new plan. Existing
      // subscribers keep their old plan and price.
      plan = await deps.api.createPlan(
        { months, amount: price, name: planName(months) },
        deps.keys(),
      );
    } catch (e) {
      logger.error("Razorpay createPlan failed", { key, error: `${e}` });
      throw new HttpsError("unavailable", "Payment service is busy. Try again.");
    }
    await getFirestore()
      .doc(ROOM_PLANS_DOC)
      .set({ [key]: { months, price, razorpayPlanId: plan.id } }, { merge: true });
    return { planKey: key, price, razorpayPlanId: plan.id };
  };
}

export const createRoomSubscription = onCall(withKeys, makeCreateRoomSubscription(realDeps));
export const verifyRoomSubscription = onCall(
  withKeys,
  makeVerifyRoomSubscription(() => RAZORPAY_KEY_SECRET.value()),
);
export const cancelRoomSubscription = onCall(withKeys, makeCancelRoomSubscription(realDeps));
export const setRoomPlanPrice = onCall(withKeys, makeSetRoomPlanPrice(realDeps));
