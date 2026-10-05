/**
 * Catalog rules. Phase 1: universities are publicly readable, not writable.
 * Phase 2 adds admin writes (and semesters, subjects, modules, notes).
 */
import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { describe, it } from "vitest";
import { setupRulesEnv } from "./helpers";

const t = setupRulesEnv();
const uni = { name: "University of Mumbai", shortName: "MU", isActive: true, order: 1 };

describe("universities", () => {
  it("anyone (even a guest) can read and list universities", async () => {
    await t.seed("universities/mu", uni);
    await assertSucceeds(t.guest().firestore().doc("universities/mu").get());
    await assertSucceeds(t.guest().firestore().collection("universities").limit(50).get());
    await assertSucceeds(t.student("alice").firestore().collection("universities").get());
  });

  it("nobody can write universities from the app yet", async () => {
    await assertFails(t.guest().firestore().doc("universities/x").set(uni));
    await assertFails(t.student("alice").firestore().doc("universities/x").set(uni));
    await assertFails(t.admin().firestore().doc("universities/x").set(uni));
  });
});
