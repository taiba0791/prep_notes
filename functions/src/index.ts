/**
 * PrepNotes Cloud Functions (2nd gen).
 *
 * Trusted server code: payments, entitlements, signed PDF URLs, admin
 * actions and stats live here (Phases 1–8). Clients can never do these.
 *
 * Money is always an integer in paise (₹49 = 4900).
 */
import "./config";
import * as logger from "firebase-functions/logger";
import { onRequest } from "firebase-functions/v2/https";

export { deleteMyAccount } from "./account/delete_my_account";
export {
  onNoteDeleted,
  onNotePdfUploaded,
  onNoteUpdated,
} from "./notes/note_files";
export { onUserProfileWritten } from "./admin/owner_admin";
export { createOrder } from "./payments/create_order";
export { getNoteFileUrl } from "./payments/note_file_url";
export { razorpayWebhook } from "./payments/webhook";
export { verifyPayment } from "./payments/verify_payment";
export { setAdminClaim } from "./admin/set_admin_claim";
export { setUserDisabled } from "./admin/set_user_disabled";
export { markOrderRefunded } from "./payments/refund_order";
export {
  expireRooms,
  onRoomFileUploaded,
  onRoomItemDeleted,
} from "./room/room_files";
export {
  cancelRoomSubscription,
  createRoomSubscription,
  setRoomPlanPrice,
  verifyRoomSubscription,
} from "./room/subscriptions";
export { recomputeStats } from "./stats/recompute_stats";
export { onNoteStatsWritten } from "./stats/stats_triggers";

/**
 * Health check: proves the Functions pipeline works.
 * GET → { status: "ok", service: "prepnotes-functions", time: ISO string }
 */
export const healthCheck = onRequest({ invoker: "public" }, (req, res) => {
  logger.info("healthCheck called", { method: req.method });
  res.json({
    status: "ok",
    service: "prepnotes-functions",
    time: new Date().toISOString(),
  });
});
