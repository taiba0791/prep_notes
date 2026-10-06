/**
 * Callable `getNoteFileUrl({ noteId })` — the ONLY way to open a full PDF.
 *
 * Allowed if: the caller owns the note (entitlement, not expired) or has an
 * active bundle for its semester, or the note is free
 * and published, or the caller is an admin. Returns a signed URL that
 * expires after 10 minutes. Rate-limited and logged.
 *
 * Production needs the functions' service account to be allowed to sign
 * (IAM role "Service Account Token Creator") — see README.
 */
import "../config";
import { randomUUID } from "node:crypto";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import {
  type CallableRequest,
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  Collections,
  NoteFields,
  STORAGE_BUCKET,
  StoragePaths,
} from "../config";
import { hasNoteAccess } from "../access/access";
import { hitRateLimit } from "./rate_limit";

export const SIGNED_URL_MINUTES = 10;

export type AccessReason = "owner" | "bundle" | "free" | "admin";

/** A short-lived link to a private file. */
export async function signedReadUrl(path: string): Promise<string> {
  const file = getStorage().bucket(STORAGE_BUCKET).file(path);
  const emulator = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
  if (emulator) {
    // The Storage emulator can't make real signed URLs; use a download
    // token instead (emulator only — never done in production).
    const [meta] = await file.getMetadata();
    let token = (meta.metadata?.firebaseStorageDownloadTokens as string) ?? "";
    if (!token) {
      token = randomUUID();
      await file.setMetadata({
        metadata: { firebaseStorageDownloadTokens: token },
      });
    }
    const host = emulator.startsWith("http") ? emulator : `http://${emulator}`;
    return `${host}/v0/b/${STORAGE_BUCKET}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
  }
  const [url] = await file.getSignedUrl({
    version: "v4",
    action: "read",
    expires: Date.now() + SIGNED_URL_MINUTES * 60 * 1000,
  });
  return url;
}

export async function handleGetNoteFileUrl(
  request: CallableRequest<unknown>,
): Promise<{ url: string; expiresInSeconds: number }> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Please sign in.");
  }
  const uid = request.auth.uid;
  const noteId = (request.data as { noteId?: unknown } | null)?.noteId;
  if (typeof noteId !== "string" || !/^[\w-]{1,128}$/.test(noteId)) {
    throw new HttpsError("invalid-argument", "Invalid note.");
  }
  await hitRateLimit(uid, "noteFileUrl");

  const db = getFirestore();
  const note = await db.collection(Collections.notes).doc(noteId).get();
  if (!note.exists) throw new HttpsError("not-found", "Note not found.");

  // Bought (not expired), or in an active semester bundle.
  let reason: AccessReason | null = await hasNoteAccess(
    uid,
    noteId,
    note.get("semesterId") as string | undefined,
  );
  if (!reason && request.auth.token.admin === true) {
    reason = "admin";
  } else if (
    !reason &&
    note.get(NoteFields.isFree) === true &&
    note.get(NoteFields.isPublished) === true
  ) {
    reason = "free";
  }
  if (!reason) {
    throw new HttpsError("permission-denied", "not-purchased");
  }

  const path = StoragePaths.notePdf(noteId);
  const [exists] = await getStorage().bucket(STORAGE_BUCKET).file(path).exists();
  if (!exists) throw new HttpsError("not-found", "File not uploaded yet.");

  const url = await signedReadUrl(path);
  await db.collection(Collections.fileAccessLogs).add({
    userId: uid,
    noteId,
    reason,
    at: FieldValue.serverTimestamp(),
  });
  return { url, expiresInSeconds: SIGNED_URL_MINUTES * 60 };
}

export const getNoteFileUrl = onCall(
  { invoker: "public" },
  handleGetNoteFileUrl,
);
