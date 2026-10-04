/**
 * Security-rules tests (Phase 0): everything is denied for everyone.
 *
 * Run with the emulators (from the project root):
 *   firebase emulators:exec --only firestore,storage "npm --prefix functions run test:rules"
 *
 * Each later phase adds a test file proving exactly which doors it opens,
 * for: guest, student (owner), another student, and admin.
 */
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  assertFails,
  initializeTestEnvironment,
  type RulesTestContext,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { afterAll, beforeAll, describe, it } from "vitest";

const PROJECT_ID = "prepnotes-635d6";
const root = resolve(__dirname, "../../..");

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: readFileSync(resolve(root, "firestore.rules"), "utf8") },
    storage: { rules: readFileSync(resolve(root, "storage.rules"), "utf8") },
  });
});

afterAll(async () => {
  await env?.cleanup();
});

/** The three kinds of client we always test as. */
const users: Record<string, () => RulesTestContext> = {
  guest: () => env.unauthenticatedContext(),
  student: () => env.authenticatedContext("student1"),
  // A client token claiming admin: even admins are denied in Phase 0.
  admin: () => env.authenticatedContext("admin1", { admin: true }),
};

describe("Firestore: deny all", () => {
  const docs = [
    "users/student1",
    "users/student1/entitlements/n1",
    "notes/n1",
    "universities/u1",
    "orders/o1",
    "feedback/f1",
    "stats/global",
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

describe("Storage: deny all", () => {
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
