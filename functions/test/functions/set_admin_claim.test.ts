/**
 * setAdminClaim — runs against the Auth + Firestore emulators.
 *   npm --prefix functions run functions:test
 */
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import type { CallableRequest } from "firebase-functions/v2/https";
import { beforeEach, describe, expect, it } from "vitest";
import { handleSetAdminClaim } from "../../src/admin/set_admin_claim";

const PROJECT_ID = "prepnotes-635d6";

/** Builds a fake callable request from a signed-in (or anonymous) caller. */
function call(
  data: unknown,
  caller?: { uid: string; admin?: boolean },
): Promise<unknown> {
  const request = {
    data,
    auth: caller
      ? { uid: caller.uid, token: { admin: caller.admin === true } }
      : undefined,
  } as unknown as CallableRequest<unknown>;
  return handleSetAdminClaim(request);
}

async function clearEmulators(): Promise<void> {
  const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const dbHost = process.env.FIRESTORE_EMULATOR_HOST;
  await fetch(`http://${authHost}/emulator/v1/projects/${PROJECT_ID}/accounts`, {
    method: "DELETE",
  });
  await fetch(
    `http://${dbHost}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
}

async function makeUser(uid: string, email: string): Promise<void> {
  await getAuth().createUser({ uid, email });
  await getFirestore().doc(`users/${uid}`).set({ name: uid, email, role: "student" });
}

const claimsOf = async (uid: string) => (await getAuth().getUser(uid)).customClaims;
const roleOf = async (uid: string) =>
  (await getFirestore().doc(`users/${uid}`).get()).get("role");

beforeEach(async () => {
  await clearEmulators();
  await makeUser("boss", "boss@example.com");
  await makeUser("alice", "alice@example.com");
});

describe("who may call it", () => {
  it("rejects signed-out callers", async () => {
    await expect(call({ email: "alice@example.com", admin: true })).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  it("rejects students (even for themselves)", async () => {
    await expect(
      call({ email: "alice@example.com", admin: true }, { uid: "alice" }),
    ).rejects.toMatchObject({ code: "permission-denied" });
    expect(await claimsOf("alice")).toBeUndefined();
  });
});

describe("input checks", () => {
  const boss = { uid: "boss", admin: true };

  it.each([
    [{}],
    [{ email: "not-an-email", admin: true }],
    [{ email: "alice@example.com" }],
    [{ email: "alice@example.com", admin: "yes" }],
  ])("rejects %j", async (data) => {
    await expect(call(data, boss)).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("unknown email → not-found", async () => {
    await expect(
      call({ email: "nobody@example.com", admin: true }, boss),
    ).rejects.toMatchObject({ code: "not-found" });
  });
});

describe("granting and removing", () => {
  const boss = { uid: "boss", admin: true };

  it("an admin can make someone an admin (email is case-insensitive)", async () => {
    const result = await call({ email: "Alice@Example.com", admin: true }, boss);
    expect(result).toMatchObject({ uid: "alice", admin: true });
    expect(await claimsOf("alice")).toEqual({ admin: true });
    expect(await roleOf("alice")).toBe("admin");
  });

  it("an admin can remove admin from someone else", async () => {
    await call({ email: "alice@example.com", admin: true }, boss);
    await call({ email: "alice@example.com", admin: false }, boss);
    expect(await claimsOf("alice")).toEqual({});
    expect(await roleOf("alice")).toBe("student");
  });

  it("keeps other custom claims", async () => {
    await getAuth().setCustomUserClaims("alice", { betaTester: true });
    await call({ email: "alice@example.com", admin: true }, boss);
    expect(await claimsOf("alice")).toEqual({ betaTester: true, admin: true });
  });

  it("an admin cannot remove their own admin access", async () => {
    await expect(
      call({ email: "boss@example.com", admin: false }, boss),
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });
});
