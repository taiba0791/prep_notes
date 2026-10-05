/**
 * Owner auto-admin — runs against the Auth + Firestore emulators.
 */
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { beforeEach, describe, expect, it } from "vitest";
import { grantAdminIfOwner } from "../../src/admin/owner_admin";

const PROJECT_ID = "prepnotes-635d6";
const OWNERS = ["owner@example.com"];

async function clearEmulators(): Promise<void> {
  await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/accounts`,
    { method: "DELETE" },
  );
  await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
}

async function makeUser(uid: string, email: string, emailVerified: boolean) {
  await getAuth().createUser({ uid, email, emailVerified });
  await getFirestore().doc(`users/${uid}`).set({ email, role: "student" });
}

const isAdmin = async (uid: string) =>
  (await getAuth().getUser(uid)).customClaims?.admin === true;

beforeEach(clearEmulators);

describe("grantAdminIfOwner", () => {
  it("verified owner becomes admin (and role is mirrored)", async () => {
    await makeUser("o1", "owner@example.com", true);
    expect(await grantAdminIfOwner("o1", "owner@example.com", OWNERS)).toBe(true);
    expect(await isAdmin("o1")).toBe(true);
    expect((await getFirestore().doc("users/o1").get()).get("role")).toBe("admin");
  });

  it("email match is case-insensitive", async () => {
    await makeUser("o1", "Owner@Example.com", true);
    expect(await grantAdminIfOwner("o1", "Owner@Example.com", OWNERS)).toBe(true);
  });

  it("UNVERIFIED owner email is not trusted", async () => {
    await makeUser("o1", "owner@example.com", false);
    expect(await grantAdminIfOwner("o1", "owner@example.com", OWNERS)).toBe(false);
    expect(await isAdmin("o1")).toBe(false);
  });

  it("ordinary students are ignored", async () => {
    await makeUser("s1", "student@example.com", true);
    expect(await grantAdminIfOwner("s1", "student@example.com", OWNERS)).toBe(false);
    expect(await isAdmin("s1")).toBe(false);
  });

  it("a profile CLAIMING the owner email doesn't help (Auth record decides)", async () => {
    await makeUser("s1", "student@example.com", true);
    expect(await grantAdminIfOwner("s1", "owner@example.com", OWNERS)).toBe(false);
    expect(await isAdmin("s1")).toBe(false);
  });

  it("already admin → nothing to do (stops the trigger loop)", async () => {
    await makeUser("o1", "owner@example.com", true);
    await grantAdminIfOwner("o1", "owner@example.com", OWNERS);
    expect(await grantAdminIfOwner("o1", "owner@example.com", OWNERS)).toBe(false);
  });

  it("empty owner list → nobody", async () => {
    await makeUser("o1", "owner@example.com", true);
    expect(await grantAdminIfOwner("o1", "owner@example.com", [])).toBe(false);
  });
});
