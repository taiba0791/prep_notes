/**
 * PrepNotes Cloud Functions (2nd gen).
 *
 * Trusted server code: payments, entitlements, signed PDF URLs, admin
 * actions and stats live here (Phases 1–8). Clients can never do these.
 *
 * Money is always an integer in paise (₹49 = 4900).
 */
import { setGlobalOptions } from "firebase-functions/v2";
import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { initializeApp } from "firebase-admin/app";

initializeApp();

// Same region as Firestore (Mumbai). maxInstances caps cost if a function
// is ever flooded with requests.
setGlobalOptions({ region: "asia-south1", maxInstances: 10 });

/**
 * Health check: proves the Functions pipeline works.
 * GET → { status: "ok", service: "prepnotes-functions", time: ISO string }
 */
export const healthCheck = onRequest((req, res) => {
  logger.info("healthCheck called", { method: req.method });
  res.json({
    status: "ok",
    service: "prepnotes-functions",
    time: new Date().toISOString(),
  });
});
