/**
 * Security-rules tests: Firestore collections not opened yet are denied for
 * everyone. (Storage rules: storage.test.ts.)
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
  // orders → orders.test.ts (Phase 4)
  const docs = [
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
  }
});
