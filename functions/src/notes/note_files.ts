/**
 * Server-side work on note PDFs (admins upload; students never see the
 * private file):
 *  - onNotePdfUploaded: reads page count + size and builds the free preview
 *    (first N pages) at notes_public/{noteId}/preview.pdf.
 *  - onNoteUpdated: rebuilds the preview when the admin changes N.
 *  - onNoteDeleted: deletes the note's private + public files.
 */
import "../config";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import * as logger from "firebase-functions/logger";
import {
  onDocumentDeleted,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import { PDFDocument } from "pdf-lib";
import {
  Collections,
  NoteFields,
  STORAGE_BUCKET,
  StoragePaths,
} from "../config";

const bucket = () => getStorage().bucket(STORAGE_BUCKET);
const noteRef = (noteId: string) =>
  getFirestore().collection(Collections.notes).doc(noteId);

/** Matches notes_private/{noteId}/file.pdf and returns the noteId. */
export function noteIdFromPdfPath(path: string | undefined): string | null {
  const match = /^notes_private\/([^/]+)\/file\.pdf$/.exec(path ?? "");
  return match ? match[1] : null;
}

/** First [pages] pages of [pdf] as a new PDF. */
export async function buildPreview(pdf: PDFDocument, pages: number): Promise<Uint8Array> {
  const preview = await PDFDocument.create();
  const indices = Array.from({ length: pages }, (_, i) => i);
  const copied = await preview.copyPages(pdf, indices);
  copied.forEach((p) => preview.addPage(p));
  return preview.save();
}

/**
 * Reads the uploaded PDF, saves pageCount / fileSizeBytes, and (re)builds
 * the preview. Safe to run more than once. Does nothing if the note
 * document doesn't exist (e.g. an abandoned upload).
 */
export async function processNotePdf(noteId: string): Promise<void> {
  const ref = noteRef(noteId);
  const snap = await ref.get();
  if (!snap.exists) {
    logger.warn("PDF uploaded for a note that doesn't exist", { noteId });
    return;
  }

  const [bytes] = await bucket().file(StoragePaths.notePdf(noteId)).download();
  const pdf = await PDFDocument.load(bytes, { ignoreEncryption: true });
  const pageCount = pdf.getPageCount();
  const wanted = Number(snap.get(NoteFields.previewPages) ?? 0);
  const previewPages = Math.max(0, Math.min(wanted, pageCount));

  const previewFile = bucket().file(StoragePaths.notePreview(noteId));
  if (previewPages > 0) {
    await previewFile.save(Buffer.from(await buildPreview(pdf, previewPages)), {
      contentType: "application/pdf",
      metadata: { cacheControl: "public, max-age=3600" },
    });
  } else {
    await previewFile.delete({ ignoreNotFound: true });
  }

  await ref.update({
    [NoteFields.pageCount]: pageCount,
    [NoteFields.fileSizeBytes]: bytes.length,
    [NoteFields.hasPreview]: previewPages > 0,
  });
  logger.info("Processed note PDF", { noteId, pageCount, previewPages });
}

/** Deletes every file stored for [noteId] (private PDF, thumbnail, preview). */
export async function deleteNoteFiles(noteId: string): Promise<void> {
  await bucket().deleteFiles({ prefix: StoragePaths.notePrivateFolder(noteId) });
  await bucket().deleteFiles({ prefix: StoragePaths.notePublicFolder(noteId) });
}

export const onNotePdfUploaded = onObjectFinalized(
  { bucket: STORAGE_BUCKET, memory: "1GiB", timeoutSeconds: 120 },
  async (event) => {
    const noteId = noteIdFromPdfPath(event.data.name);
    if (!noteId) return; // not a note PDF (avatars, thumbnails, ...)
    await processNotePdf(noteId);
  },
);

export const onNoteUpdated = onDocumentUpdated(
  { document: "notes/{noteId}", memory: "1GiB", timeoutSeconds: 120 },
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before || !after) return;
    const previewChanged =
      before.get(NoteFields.previewPages) !== after.get(NoteFields.previewPages);
    if (previewChanged && after.get(NoteFields.storagePath)) {
      await processNotePdf(event.params.noteId);
    }
  },
);

export const onNoteDeleted = onDocumentDeleted("notes/{noteId}", async (event) => {
  await deleteNoteFiles(event.params.noteId);
  logger.info("Deleted note files", { noteId: event.params.noteId });
});
