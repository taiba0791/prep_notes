/**
 * HTTPS `razorpayWebhook` — Razorpay calls this directly, so a purchase is
 * completed even if the student closed the tab before the app could call
 * verifyPayment. Every request must carry a valid X-Razorpay-Signature.
 *
 * Events: payment.captured / order.paid → grant; payment.failed → mark failed.
 * Set up in Razorpay Dashboard → Settings → Webhooks (see README).
 */
import "../config";
import * as logger from "firebase-functions/logger";
import { onRequest } from "firebase-functions/v2/https";
import { grantOrder, markOrderFailed } from "./grant";
import { isValidWebhookSignature, RAZORPAY_WEBHOOK_SECRET } from "./razorpay";

interface PaymentEntity {
  id?: string;
  order_id?: string;
  amount?: number;
  error_description?: string;
}

interface WebhookBody {
  event?: string;
  payload?: { payment?: { entity?: PaymentEntity } };
}

export interface WebhookRequest {
  method: string;
  rawBody: Buffer;
  header: (name: string) => string | undefined;
}

export async function handleWebhook(
  req: WebhookRequest,
  webhookSecret: string,
): Promise<{ code: number; body: string }> {
  if (req.method !== "POST") return { code: 405, body: "method" };
  const signature = req.header("x-razorpay-signature") ?? "";
  if (!isValidWebhookSignature(req.rawBody, signature, webhookSecret)) {
    logger.warn("Webhook with bad signature");
    return { code: 400, body: "signature" };
  }

  let body: WebhookBody;
  try {
    body = JSON.parse(req.rawBody.toString("utf8")) as WebhookBody;
  } catch {
    return { code: 400, body: "json" };
  }
  const payment = body.payload?.payment?.entity;
  const orderId = payment?.order_id;
  if (!payment?.id || !orderId) return { code: 200, body: "ignored" };

  switch (body.event) {
    case "payment.captured":
    case "order.paid": {
      const result = await grantOrder(orderId, payment.id, payment.amount);
      if (result.status === "amount-mismatch") {
        logger.error("Webhook amount mismatch", { orderId, paid: payment.amount });
      }
      return { code: 200, body: result.status };
    }
    case "payment.failed":
      await markOrderFailed(
        orderId,
        payment.error_description ?? "Payment failed",
      );
      return { code: 200, body: "failed-recorded" };
    default:
      return { code: 200, body: "ignored" };
  }
}

export const razorpayWebhook = onRequest(
  { invoker: "public", secrets: [RAZORPAY_WEBHOOK_SECRET] },
  async (req, res) => {
    try {
      const out = await handleWebhook(
        { method: req.method, rawBody: req.rawBody, header: (n) => req.get(n) },
        RAZORPAY_WEBHOOK_SECRET.value(),
      );
      res.status(out.code).send(out.body);
    } catch (e) {
      // 500 → Razorpay retries later.
      logger.error("Webhook failed", { error: `${e}` });
      res.status(500).send("error");
    }
  },
);
