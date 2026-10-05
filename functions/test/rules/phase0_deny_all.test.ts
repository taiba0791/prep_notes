/**
 * Security-rules tests: collections not opened yet are denied for everyone.
 *
 * Run (from the project root):  npm --prefix functions run rules:test
 *
 * When a phase opens a collection, move it out of this file into its own
 * test file (e.g. users → users.test.ts in Phase 1).
 */
import { assertFails } from "@firebase/rules-unit-testing";
import { describe, it } from "vitest";
import { setupRulesEnv } from "./helpers";

const t = setupRulesEnv();

const users = {
  guest: () => t.guest(),
  student: () => t.student("student1"),
  // A token claiming admin: still denied until each collection's phase.
  admin: () => t.admin(),
};

describe("Firestore: not-yet-opened collections are denied", () => {
  const docs = [
    "notes/n1", // Phase 2
    "universities/u1", // Phase 2
    "orders/o1", // Phase 4
    "feedback/f1", // Phase 7
    "stats/global", // Phase 5
    "users/student1/studySessions/s1", // Phase 8
  ];

  for (const [who, ctx] of Object.entries(users)) {
    for (const path of docs) {
      it(`${who} cannot read ${path}`, async () => {
        await assertFails(ctx().firestore().doc(path).get());
      });

      it(`${who} cannot write ${path}`, async () => {
        await assertFails(ctx().firestore().doc(path).set({ hacked: true }));
      });
    }

    it(`${who} cannot list notes`, async () => {
      await assertFails(ctx().firestore().collection("notes").get());
    });
  }
});

describe("Storage: deny all (until Step 1.9)", () => {
  const files = [
    "notes_private/n1/file.pdf",
    "notes_public/n1/thumbnail.jpg",
    "avatars/student1/avatar.jpg",
  ];

  for (const [who, ctx] of Object.entries(users)) {
    for (const path of files) {
      it(`${who} cannot read ${path}`, async () => {
        await assertFails(ctx().storage().ref(path).getDownloadURL());
      });

      it(`${who} cannot upload to ${path}`, async () => {
        await assertFails(ctx().storage().ref(path).putString("x"));
      });
    }
  }
});
