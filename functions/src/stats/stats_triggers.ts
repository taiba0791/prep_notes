/**
 * Keeps stats/global in step with users and notes, and keeps the
 * lower-case name used by admin search.
 *
 * Triggers can (rarely) run twice; if numbers ever drift, an admin presses
 * "Recalculate stats" (recomputeStats).
 */
import "../config";
import { getFirestore } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { NoteFields, StatsFields, UserFields } from "../config";
import { bumpGlobal } from "./stats";

type Snap = { exists: boolean; get: (field: string) => unknown } | undefined;

/** +1 / −1 / 0 for "document appeared / disappeared / still there". */
export function existenceDelta(before: Snap, after: Snap): number {
  return (after?.exists ? 1 : 0) - (before?.exists ? 1 : 0);
}

/** +1 / −1 / 0 for "note became published / unpublished / unchanged". */
export function publishedDelta(before: Snap, after: Snap): number {
  const was = before?.exists === true && before.get(NoteFields.isPublished) === true;
  const is = after?.exists === true && after.get(NoteFields.isPublished) === true;
  return (is ? 1 : 0) - (was ? 1 : 0);
}

/** users/{uid} written: count students, keep nameLower in sync. */
export async function onUserWritten(
  uid: string,
  before: Snap,
  after: Snap,
): Promise<void> {
  const db = getFirestore();
  const delta = existenceDelta(before, after);
  if (delta !== 0) {
    await db.runTransaction(async (tx) =>
      bumpGlobal(tx, { [StatsFields.totalStudents]: delta }),
    );
  }
  if (after?.exists) {
    const name = after.get(UserFields.name);
    const lower = typeof name === "string" ? name.trim().toLowerCase() : "";
    // Only write when it changed, so this doesn't trigger itself forever.
    if (after.get(UserFields.nameLower) !== lower) {
      await db.doc(`users/${uid}`).update({ [UserFields.nameLower]: lower });
    }
  }
}

export const onNoteStatsWritten = onDocumentWritten(
  "notes/{noteId}",
  async (event) => {
    const delta = publishedDelta(event.data?.before, event.data?.after);
    if (delta === 0) return;
    await getFirestore().runTransaction(async (tx) =>
      bumpGlobal(tx, { [StatsFields.totalNotes]: delta }),
    );
  },
);
