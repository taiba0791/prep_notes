/**
 * Fills the catalog with SAMPLE data for development:
 * 2 universities × 2 semesters × 3 subjects × 2 modules, and 5 published
 * notes with generated PDFs (page count + preview are processed too).
 *
 * Fixed ids (seed-…) → running it again updates instead of duplicating.
 *
 *   Emulators:      npm --prefix functions run seed -- --emulator
 *   Real project:   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\…\prepnotes-sa.json"
 *                   npm --prefix functions run seed
 */
import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { PDFDocument, rgb, StandardFonts } from "pdf-lib";

const PROJECT_ID = "prepnotes-635d6";
const BUCKET = "prepnotes-635d6.firebasestorage.app";

const useEmulator = process.argv.includes("--emulator");
if (useEmulator) {
  process.env.FIRESTORE_EMULATOR_HOST ??= "127.0.0.1:8080";
  process.env.FIREBASE_STORAGE_EMULATOR_HOST ??= "127.0.0.1:9199";
} else if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error("Set GOOGLE_APPLICATION_CREDENTIALS first, or pass --emulator.");
  process.exit(1);
}
initializeApp({ projectId: PROJECT_ID, storageBucket: BUCKET });
const db = getFirestore();
const bucket = getStorage().bucket(BUCKET);

/** Same rules as lib/data/search_keywords.dart. */
function keywords(texts: string[]): string[] {
  const words = new Set<string>();
  for (const t of texts) {
    for (const w of t.toLowerCase().split(/[^a-z0-9+#]+/)) if (w) words.add(w);
  }
  const out = new Set<string>();
  for (const w of words) {
    if (w.length < 2) {
      out.add(w);
      continue;
    }
    for (let i = 2; i <= Math.min(w.length, 20); i++) out.add(w.slice(0, i));
    out.add(w);
  }
  return [...out].sort().slice(0, 300);
}

async function samplePdf(title: string, pages: number): Promise<Buffer> {
  const doc = await PDFDocument.create();
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  for (let i = 1; i <= pages; i++) {
    const page = doc.addPage([595, 842]); // A4
    page.drawRectangle({ x: 0, y: 782, width: 595, height: 60, color: rgb(0.56, 0.11, 0.25) });
    page.drawText("PrepNotes · SAMPLE", { x: 40, y: 805, size: 16, font: bold, color: rgb(1, 1, 1) });
    page.drawText(title, { x: 40, y: 730, size: 20, font: bold });
    page.drawText(`Page ${i} of ${pages}`, { x: 40, y: 700, size: 12, font });
    for (let line = 0; line < 20; line++) {
      page.drawText("Sample content for development and testing only.", {
        x: 40, y: 660 - line * 24, size: 11, font, color: rgb(0.35, 0.33, 0.33),
      });
    }
  }
  return Buffer.from(await doc.save());
}

const universities = [
  { id: "seed-mu", name: "University of Mumbai", shortName: "MU", city: "Mumbai", order: 1 },
  { id: "seed-sppu", name: "Savitribai Phule Pune University", shortName: "SPPU", city: "Pune", order: 2 },
];
const subjectsBySem: Record<number, string[]> = {
  3: ["Data Structures", "Digital Logic", "Discrete Mathematics"],
  4: ["Operating Systems", "Database Management Systems", "Computer Networks"],
};

async function main(): Promise<void> {
  const subjects: Array<{ id: string; name: string; uni: (typeof universities)[number]; sem: number; semId: string }> = [];
  const modules: Record<string, Array<{ id: string; title: string }>> = {};

  for (const u of universities) {
    const { id, ...data } = u;
    await db.doc(`universities/${id}`).set({ ...data, description: `${data.name} (sample)`, isActive: true });

    for (const sem of [3, 4]) {
      const semId = `${id}-s${sem}`;
      await db.doc(`semesters/${semId}`).set({ universityId: id, number: sem, name: `Semester ${sem}`, isActive: true });

      for (const [i, name] of subjectsBySem[sem].entries()) {
        const subId = `${semId}-sub${i + 1}`;
        await db.doc(`subjects/${subId}`).set({
          universityId: id, semesterId: semId, name,
          code: `${u.shortName}${sem}0${i + 1}`, description: "", isActive: true,
        });
        subjects.push({ id: subId, name, uni: u, sem, semId });
        modules[subId] = [];
        for (const m of [1, 2]) {
          const modId = `${subId}-m${m}`;
          const title = m === 1 ? "Fundamentals" : "Advanced Topics";
          await db.doc(`modules/${modId}`).set({ subjectId: subId, number: m, title, isActive: true });
          modules[subId].push({ id: modId, title });
        }
      }
    }
  }

  const prices = [14900, 9900, 12900, 0, 4900];
  for (let n = 0; n < 5; n++) {
    const s = subjects[n * 2];
    const mod = modules[s.id][0];
    const noteId = `seed-note-${n + 1}`;
    const title = `${s.name}: Complete Notes (Sample ${n + 1})`;
    const price = prices[n];

    await db.doc(`notes/${noteId}`).set({
      title,
      description: "Sample note created by the seed script.",
      universityId: s.uni.id, semesterId: s.semId, subjectId: s.id, moduleId: mod.id,
      universityName: s.uni.name, semesterNumber: s.sem, subjectName: s.name, moduleTitle: mod.title,
      price, isFree: price === 0,
      pageCount: 0, fileSizeBytes: 0, previewPages: 3, hasPreview: false,
      storagePath: `notes_private/${noteId}/file.pdf`,
      isPublished: true, purchaseCount: 0,
      tags: ["sample"],
      searchKeywords: keywords([title, s.name, s.uni.name, s.uni.shortName, mod.title, "sample"]),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    await bucket.file(`notes_private/${noteId}/file.pdf`).save(
      await samplePdf(title, 12 + n * 4),
      { contentType: "application/pdf" },
    );
  }

  // Page counts + previews (same code the Cloud Function runs).
  const { processNotePdf } = await import("../src/notes/note_files");
  for (let n = 1; n <= 5; n++) await processNotePdf(`seed-note-${n}`);

  console.log(
    `Seeded ${universities.length} universities, 4 semesters, ${subjects.length} subjects, ` +
      `${subjects.length * 2} modules and 5 notes on ${useEmulator ? "the EMULATOR" : PROJECT_ID}.`,
  );
}

main().catch((err: unknown) => {
  console.error("Seed failed:", err instanceof Error ? err.message : err);
  process.exit(1);
});
