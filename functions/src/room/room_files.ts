/**
 * Resource Room housekeeping:
 *  - onRoomFileUploaded: enforces 25 MB per file / 200 MB per student and
 *    keeps users/{uid}.roomBytes up to date.
 *  - onRoomItemDeleted: deletes the item's uploaded file.
 *  - expireRooms (daily, 03:00 India time): when a student's Room access
 *    has ended (no active bundle or subscription), deletes their saved
 *    items and files — as promised in the Terms.
 */
import "../config";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import * as logger from "firebase-functions/logger";
import { onDocumentDeleted } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import {
  Collections,
  ROOM_MAX_FILE_BYTES,
  ROOM_QUOTA_BYTES,
  RoomItemFields,
  STORAGE_BUCKET,
  STORAGE_TRIGGER_REGION,
  StoragePaths,
  UserFields,
} from "../config";
import { roomAccessEnd } from "../access/access";

const bucket = () => getStorage().bucket(STORAGE_BUCKET);
const userRef = (uid: string) =>
  getFirestore().collection(Collections.users).doc(uid);

/** room/{uid}/{itemId}/{fileName} → parts, or null. */
export function parseRoomPath(
  path: string | undefined,
): { uid: string; itemId: string } | null {
  const m = /^room\/([^/]+)\/([^/]+)\/[^/]+$/.exec(path ?? "");
  return m ? { uid: m[1], itemId: m[2] } : null;
}

/** Bytes used by all of [uid]'s Room uploads. */
export async function roomUsage(uid: string): Promise<number> {
  const [files] = await bucket().getFiles({ prefix: StoragePaths.roomFolder(uid) });
  return files.reduce((sum, f) => sum + Number(f.metadata.size ?? 0), 0);
}

/** Checks a new upload; returns what happened. */
export async function checkRoomUpload(
  path: string,
  size: number,
  limits = { file: ROOM_MAX_FILE_BYTES, quota: ROOM_QUOTA_BYTES },
): Promise<"ok" | "too-big" | "over-quota" | "ignored"> {
  const parts = parseRoomPath(path);
  if (!parts) return "ignored";
  const used = await roomUsage(parts.uid);
  const verdict =
    size > limits.file ? "too-big" : used > limits.quota ? "over-quota" : "ok";
  if (verdict !== "ok") {
    await bucket().file(path).delete({ ignoreNotFound: true });
    await userRef(parts.uid)
      .collection(Collections.roomItems)
      .doc(parts.itemId)
      .delete();
    logger.warn("Room upload rejected", { path, size, used, verdict });
  }
  await userRef(parts.uid).set(
    { [UserFields.roomBytes]: verdict === "ok" ? used : used - size },
    { merge: true },
  );
  return verdict;
}

export const onRoomFileUploaded = onObjectFinalized(
  { bucket: STORAGE_BUCKET, region: STORAGE_TRIGGER_REGION },
  async (event) => {
    if (!event.data.name?.startsWith("room/")) return;
    await checkRoomUpload(event.data.name, Number(event.data.size ?? 0));
  },
);

/** Deletes the item's file and refreshes the usage counter. */
export async function deleteRoomItemFiles(uid: string, itemId: string): Promise<void> {
  await bucket().deleteFiles({ prefix: `${StoragePaths.roomFolder(uid)}${itemId}/` });
  if ((await userRef(uid).get()).exists) {
    await userRef(uid).update({ [UserFields.roomBytes]: await roomUsage(uid) });
  }
}

export const onRoomItemDeleted = onDocumentDeleted(
  "users/{uid}/roomItems/{itemId}",
  async (event) => {
    if (!event.data?.get(RoomItemFields.storagePath)) return; // a link
    await deleteRoomItemFiles(event.params.uid, event.params.itemId);
  },
);

/**
 * Users whose roomAccessUntil has passed: if a renewal arrived meanwhile,
 * move the date forward; otherwise delete everything in their Room.
 */
export async function expireRoomsNow(now = Date.now()): Promise<string[]> {
  const db = getFirestore();
  const due = await db
    .collection(Collections.users)
    .where(UserFields.roomAccessUntil, "<=", Timestamp.fromMillis(now))
    .limit(500)
    .get();
  const wiped: string[] = [];
  for (const user of due.docs) {
    const end = await roomAccessEnd(user.id);
    if (end > now) {
      await user.ref.update({ [UserFields.roomAccessUntil]: Timestamp.fromMillis(end) });
      continue;
    }
    await db.recursiveDelete(user.ref.collection(Collections.roomItems));
    await bucket().deleteFiles({ prefix: StoragePaths.roomFolder(user.id) });
    await user.ref.update({
      [UserFields.roomAccessUntil]: null,
      [UserFields.roomBytes]: 0,
    });
    wiped.push(user.id);
  }
  if (wiped.length) logger.info("Resource Rooms expired", { count: wiped.length });
  return wiped;
}

export const expireRooms = onSchedule(
  { schedule: "every day 03:00", timeZone: "Asia/Kolkata" },
  async () => {
    await expireRoomsNow();
  },
);
