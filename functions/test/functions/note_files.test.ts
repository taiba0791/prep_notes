/**
 * Note PDF processing — runs against the Firestore + Storage emulators.
 */
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { PDFDocument, StandardFonts } from "pdf-lib";
import { beforeEach, describe, expect, it } from "vitest";
import { STORAGE_BUCKET } from "../../src/config";
import {
  deleteNoteFiles,
  noteIdFromPdfPath,
  processNotePdf,
} from "../../src/notes/note_files";

const PROJECT_ID = "prepnotes-635d6";
const bucket = () => getStorage().bucket(STORAGE_BUCKET);
const db = () => getFirestore();

async function makePdf(pages: number): Promise<Buffer> {
  const doc = await PDFDocument.create();
  const font = await doc.embedFont(StandardFonts.Helvetica);
  for (let i = 1; i <= pages; i++) {
    doc.addPage().drawText(`Page ${i}`, { x: 50, y: 700, font, size: 24 });
  }
  return Buffer.from(await doc.save());
}

async function pageCountOf(path: string): Promise<number> {
  const [bytes] = await bucket().file(path).download();
  return (await PDFDocument.load(bytes)).getPageCount();
}

const exists = async (path: string) => (await bucket().file(path).exists())[0];

beforeEach(async () => {
  await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
});

describe("noteIdFromPdfPath", () => {
  it("only matches note PDFs", () => {
    expect(noteIdFromPdfPath("notes_private/abc/file.pdf")).toBe("abc");
    expect(noteIdFromPdfPath("notes_public/abc/preview.pdf")).toBeNull();
    expect(noteIdFromPdfPath("avatars/u1/avatar.jpg")).toBeNull();
    expect(noteIdFromPdfPath(undefined)).toBeNull();
  });
});

describe("processNotePdf", () => {
  it("saves page count + size and builds a preview of the first N pages", async () => {
    const pdf = await makePdf(12);
    await db().doc("notes/n1").set({ title: "DS", previewPages: 3, storagePath: "x" });
    await bucket().file("notes_private/n1/file.pdf").save(pdf);

    await processNotePdf("n1");

    const note = (await db().doc("notes/n1").get()).data()!;
    expect(note.pageCount).toBe(12);
    expect(note.fileSizeBytes).toBe(pdf.length);
    expect(note.hasPreview).toBe(true);
    expect(await pageCountOf("notes_public/n1/preview.pdf")).toBe(3);
  });

  it("preview never has more pages than the PDF", async () => {
    await db().doc("notes/n2").set({ title: "DS", previewPages: 10 });
    await bucket().file("notes_private/n2/file.pdf").save(await makePdf(4));
    await processNotePdf("n2");
    expect(await pageCountOf("notes_public/n2/preview.pdf")).toBe(4);
  });

  it("previewPages = 0 → no preview", async () => {
    await db().doc("notes/n3").set({ title: "DS", previewPages: 0 });
    await bucket().file("notes_private/n3/file.pdf").save(await makePdf(5));
    await bucket().file("notes_public/n3/preview.pdf").save(Buffer.from("old"));
    await processNotePdf("n3");

    expect((await db().doc("notes/n3").get()).get("hasPreview")).toBe(false);
    expect(await exists("notes_public/n3/preview.pdf")).toBe(false);
  });

  it("ignores a PDF whose note document doesn't exist", async () => {
    await bucket().file("notes_private/ghost/file.pdf").save(await makePdf(2));
    await expect(processNotePdf("ghost")).resolves.toBeUndefined();
    expect((await db().doc("notes/ghost").get()).exists).toBe(false);
  });
});

describe("deleteNoteFiles", () => {
  it("removes the note's private and public files only", async () => {
    for (const p of [
      "notes_private/d1/file.pdf",
      "notes_public/d1/thumbnail.jpg",
      "notes_public/d1/preview.pdf",
      "notes_private/keep/file.pdf",
    ]) {
      await bucket().file(p).save(Buffer.from("x"));
    }
    await deleteNoteFiles("d1");
    expect(await exists("notes_private/d1/file.pdf")).toBe(false);
    expect(await exists("notes_public/d1/thumbnail.jpg")).toBe(false);
    expect(await exists("notes_public/d1/preview.pdf")).toBe(false);
    expect(await exists("notes_private/keep/file.pdf")).toBe(true);
  });
});
