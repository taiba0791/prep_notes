/**
 * deleteMyAccount — runs against the Auth + Firestore + Storage emulators.
 */
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import type { CallableRequest } from "firebase-functions/v2/https";
import { beforeEach, describe, expect, it } from "vitest";
import {
  handleDeleteMyAccount,
  RECENT_LOGIN_SECONDS,
} from "../../src/account/delete_my_account";
import { STORAGE_BUCKET } from "../../src/config";

const PROJECT_ID = "prepnotes-635d6";
const now = () => Math.floor(Date.now() / 1000);

function call(uid?: string, authTime = now()) {
  return handleDeleteMyAccount({
    data: {},
    auth: uid ? { uid, token: { auth_time: authTime } } : undefined,
  } as unknown as CallableRequest<unknown>);
}

const db = () => getFirestore();
const bucket = () => getStorage().bucket(STORAGE_BUCKET);

async function clearEmulators(): Promise<void> {
  await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/accounts`,
    { method: "DELETE" },
  );
  await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
}

beforeEach(async () => {
  await clearEmulators();
  for (const uid of ["alice", "bob"]) {
    await getAuth().createUser({ uid, email: `${uid}@example.com` });
    await db().doc(`users/${uid}`).set({ name: uid, role: "student" });
    await db().doc(`users/${uid}/entitlements/n1`).set({ noteId: "n1" });
    await db().doc(`users/${uid}/studySessions/s1`).set({ durationSec: 60 });
    await bucket().file(`avatars/${uid}/avatar.jpg`).save(Buffer.from("img"));
  }
  await db().doc("orders/o1").set({ userId: "alice", amount: 4900 });
  await db().doc("orders/o2").set({ userId: "bob", amount: 9900 });
});

describe("deleteMyAccount", () => {
  it("rejects signed-out callers", async () => {
    await expect(call()).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("requires a recent sign-in", async () => {
    await expect(
      call("alice", now() - RECENT_LOGIN_SECONDS - 60),
    ).rejects.toMatchObject({ code: "failed-precondition" });
    expect((await db().doc("users/alice").get()).exists).toBe(true);
  });

  it("deletes login, profile, sub-collections and photo; keeps orders", async () => {
    await expect(call("alice")).resolves.toEqual({ deleted: true });

    await expect(getAuth().getUser("alice")).rejects.toMatchObject({
      code: "auth/user-not-found",
    });
    expect((await db().doc("users/alice").get()).exists).toBe(false);
    expect((await db().collection("users/alice/entitlements").get()).empty).toBe(true);
    expect((await db().collection("users/alice/studySessions").get()).empty).toBe(true);
    const [avatarExists] = await bucket().file("avatars/alice/avatar.jpg").exists();
    expect(avatarExists).toBe(false);

    const order = await db().doc("orders/o1").get();
    expect(order.exists).toBe(true);
    expect(order.get("userDeleted")).toBe(true);
    expect(order.get("amount")).toBe(4900);
  });

  it("never touches another user's data", async () => {
    await call("alice");
    expect((await getAuth().getUser("bob")).uid).toBe("bob");
    expect((await db().doc("users/bob").get()).exists).toBe(true);
    const [bobAvatar] = await bucket().file("avatars/bob/avatar.jpg").exists();
    expect(bobAvatar).toBe(true);
    expect((await db().doc("orders/o2").get()).get("userDeleted")).toBeUndefined();
  });
});
