/**
 * Catalog rules (Phase 2): public reads, admin-only writes with field checks;
 * notes visible to students only when published.
 */
import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { describe, it } from "vitest";
import { serverTimestamp, setupRulesEnv } from "./helpers";

const t = setupRulesEnv();

const uni = { name: "University of Mumbai", shortName: "MU", isActive: true, order: 1 };
const sem = { universityId: "mu", number: 3, name: "Semester 3", isActive: true };
const sub = { universityId: "mu", semesterId: "s3", name: "Data Structures", code: "CS301", isActive: true };
const mod = { subjectId: "ds", number: 1, title: "Arrays and Lists", isActive: true };

const db = (ctx: ReturnType<typeof t.guest>) => ctx.firestore();

describe("universities / semesters / subjects / modules", () => {
  const cases: Array<[string, Record<string, unknown>]> = [
    ["universities/mu", uni],
    ["semesters/s3", sem],
    ["subjects/ds", sub],
    ["modules/m1", mod],
  ];

  for (const [path, data] of cases) {
    it(`${path}: anyone reads; only admins write`, async () => {
      await t.seed(path, data);
      await assertSucceeds(db(t.guest()).doc(path).get());
      await assertFails(db(t.guest()).doc(path).set(data));
      await assertFails(db(t.student("alice")).doc(path).set(data));
      await assertFails(db(t.student("alice")).doc(path).delete());
      await assertSucceeds(db(t.admin()).doc(path).set(data));
      await assertSucceeds(db(t.admin()).doc(path).delete());
    });
  }

  it("rejects bad catalog data even from admins", async () => {
    const admin = db(t.admin());
    await assertFails(admin.doc("universities/x").set({ ...uni, name: "M" }));
    await assertFails(admin.doc("universities/x").set({ ...uni, order: "1" }));
    await assertFails(admin.doc("universities/x").set({ ...uni, hacked: true }));
    await assertFails(admin.doc("semesters/x").set({ ...sem, number: 13 }));
    await assertFails(admin.doc("modules/x").set({ ...mod, number: 0 }));
  });
});

describe("notes", () => {
  const pdfPath = (id: string) => `notes_private/${id}/file.pdf`;
  const newNote = (overrides: Record<string, unknown> = {}) => ({
    title: "Data Structures: Complete Notes",
    description: "Modules 1–4",
    universityId: "mu",
    semesterId: "s3",
    subjectId: "ds",
    moduleId: "m1",
    universityName: "University of Mumbai",
    semesterNumber: 3,
    subjectName: "Data Structures",
    moduleTitle: "Arrays",
    price: 14900,
    isFree: false,
    pageCount: 0,
    fileSizeBytes: 0,
    previewPages: 3,
    hasPreview: false,
    isPublished: false,
    purchaseCount: 0,
    tags: ["ds"],
    searchKeywords: ["da", "data"],
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  });
  const stored = (overrides: Record<string, unknown> = {}) => ({
    ...newNote(),
    createdAt: new Date(),
    updatedAt: new Date(),
    storagePath: pdfPath("n1"),
    pageCount: 120,
    fileSizeBytes: 8_400_000,
    purchaseCount: 7,
    ...overrides,
  });

  it("students see published notes, not drafts", async () => {
    await t.seed("notes/pub", stored({ isPublished: true, storagePath: pdfPath("pub") }));
    await t.seed("notes/draft", stored({ isPublished: false }));
    await assertSucceeds(db(t.guest()).doc("notes/pub").get());
    await assertFails(db(t.guest()).doc("notes/draft").get());
    await assertFails(db(t.student("alice")).doc("notes/draft").get());
    await assertSucceeds(db(t.admin()).doc("notes/draft").get());
    // A student query must ask for published notes only.
    await assertSucceeds(
      db(t.guest()).collection("notes").where("isPublished", "==", true).get(),
    );
    await assertFails(db(t.guest()).collection("notes").get());
  });

  it("admin can create a draft note; students can't", async () => {
    await assertSucceeds(db(t.admin()).doc("notes/n1").set(newNote()));
    await assertFails(db(t.student("alice")).doc("notes/n2").set(newNote()));
  });

  const badCreates: Array<[string, Record<string, unknown>]> = [
    ["a fractional price", { price: 149.5 }],
    ["a negative price", { price: -100 }],
    ["paid with price 0", { price: 0, isFree: false }],
    ["preset purchase count", { purchaseCount: 500 }],
    ["preset page count", { pageCount: 99 }],
    ["published without a PDF", { isPublished: true }],
    ["an unknown field", { secret: "x" }],
    ["a 2-letter title", { title: "DS" }],
  ];
  for (const [label, override] of badCreates) {
    it(`rejects a note with ${label}`, async () => {
      await assertFails(db(t.admin()).doc("notes/n1").set(newNote(override)));
    });
  }

  it("isFeatured must be true/false", async () => {
    await assertSucceeds(db(t.admin()).doc("notes/n1").set(newNote({ isFeatured: true })));
    await assertFails(db(t.admin()).doc("notes/n2").set(newNote({ isFeatured: "yes" })));
  });

  it("student browse queries (published only) are allowed", async () => {
    const notes = db(t.guest()).collection("notes").where("isPublished", "==", true);
    await assertSucceeds(notes.where("subjectId", "==", "ds").orderBy("updatedAt", "desc").limit(12).get());
    await assertSucceeds(notes.where("price", "==", 0).orderBy("updatedAt", "desc").limit(12).get());
    await assertSucceeds(notes.where("price", ">=", 1).orderBy("price").limit(12).get());
    await assertSucceeds(notes.where("searchKeywords", "array-contains", "data").limit(30).get());
    // Without the published filter: denied.
    await assertFails(db(t.guest()).collection("notes").where("subjectId", "==", "ds").get());
  });

  it("free notes can have price 0", async () => {
    await assertSucceeds(db(t.admin()).doc("notes/n1").set(newNote({ isFree: true, price: 0 })));
  });

  it("admin can publish once the PDF is attached", async () => {
    await t.seed("notes/n1", stored());
    await assertSucceeds(
      db(t.admin()).doc("notes/n1").update({ isPublished: true, updatedAt: serverTimestamp() }),
    );
  });

  it("admin can't edit Function-owned fields", async () => {
    await t.seed("notes/n1", stored());
    for (const field of ["pageCount", "fileSizeBytes", "hasPreview", "purchaseCount"]) {
      await assertFails(
        db(t.admin()).doc("notes/n1").update({
          [field]: field === "hasPreview" ? true : 1,
          updatedAt: serverTimestamp(),
        }),
      );
    }
  });

  it("students can't edit or delete notes", async () => {
    await t.seed("notes/n1", stored({ isPublished: true }));
    await assertFails(
      db(t.student("alice")).doc("notes/n1").update({ price: 100, updatedAt: serverTimestamp() }),
    );
    await assertFails(db(t.student("alice")).doc("notes/n1").delete());
  });
});
