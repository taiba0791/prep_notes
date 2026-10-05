/**
 * Shared set-up for security-rules tests.
 *
 * Each test file calls `setupRulesEnv()` once. The emulator must be running:
 *   npm --prefix functions run rules:test   (starts and stops it for you)
 */
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  initializeTestEnvironment,
  type RulesTestContext,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import firebase from "firebase/compat/app";
import "firebase/compat/firestore";
import { afterAll, afterEach, beforeAll } from "vitest";

export const PROJECT_ID = "prepnotes-635d6";
const root = resolve(__dirname, "../../..");

/** Firestore server timestamp (compat API, as used by the test contexts). */
export const serverTimestamp = () =>
  firebase.firestore.FieldValue.serverTimestamp();

export interface RulesEnv {
  env: () => RulesTestEnvironment;
  guest: () => RulesTestContext;
  /** A signed-in student with a matching email in their token. */
  student: (uid: string) => RulesTestContext;
  /** A user whose ID token carries `admin: true`. */
  admin: (uid?: string) => RulesTestContext;
  /** Write data directly, bypassing the rules (test set-up only). */
  seed: (path: string, data: Record<string, unknown>) => Promise<void>;
}

export function setupRulesEnv(): RulesEnv {
  let env: RulesTestEnvironment;

  beforeAll(async () => {
    env = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: readFileSync(resolve(root, "firestore.rules"), "utf8"),
      },
      storage: { rules: readFileSync(resolve(root, "storage.rules"), "utf8") },
    });
  });

  afterEach(async () => {
    await env.clearFirestore();
  });

  afterAll(async () => {
    await env?.cleanup();
  });

  return {
    env: () => env,
    guest: () => env.unauthenticatedContext(),
    student: (uid) =>
      env.authenticatedContext(uid, { email: `${uid}@example.com` }),
    admin: (uid = "admin1") =>
      env.authenticatedContext(uid, {
        email: `${uid}@example.com`,
        admin: true,
      }),
    seed: (path, data) =>
      env.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().doc(path).set(data);
      }),
  };
}
