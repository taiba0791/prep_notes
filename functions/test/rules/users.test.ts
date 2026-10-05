/**
 * Rules for users/{uid} and users/{uid}/entitlements/{noteId} (Phase 1).
 * Actors: guest, owner (alice), another student (bob), admin.
 */
import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { describe, it } from "vitest";
import { serverTimestamp, setupRulesEnv } from "./helpers";

const t = setupRulesEnv();

const alicePath = "users/alice";

/** What the app's UserRepository.createProfileIfMissing writes. */
const newProfile = (overrides: Record<string, unknown> = {}) => ({
  name: "Alice Rao",
  email: "alice@example.com",
  role: "student",
  totalStudyMinutes: 0,
  createdAt: serverTimestamp(),
  lastLoginAt: serverTimestamp(),
  ...overrides,
});

/** An existing profile, as stored (plain dates, seeded without rules). */
const storedProfile = {
  name: "Alice Rao",
  email: "alice@example.com",
  role: "student",
  totalStudyMinutes: 0,
  createdAt: new Date("2026-10-01T10:00:00Z"),
  lastLoginAt: new Date("2026-10-01T10:00:00Z"),
};

const db = (ctx: ReturnType<typeof t.guest>) => ctx.firestore();

describe("users: create", () => {
  it("owner can create their own valid profile", async () => {
    await assertSucceeds(db(t.student("alice")).doc(alicePath).set(newProfile()));
  });

  it("owner can include optional fields", async () => {
    await assertSucceeds(
      db(t.student("alice"))
        .doc(alicePath)
        .set(newProfile({ photoUrl: "https://x/p.jpg", universityId: "mu", semester: 3 })),
    );
  });

  it("guest cannot create a profile", async () => {
    await assertFails(db(t.guest()).doc(alicePath).set(newProfile()));
  });

  it("cannot create someone else's profile", async () => {
    await assertFails(db(t.student("bob")).doc(alicePath).set(newProfile()));
  });

  const sneaky: Array<[string, Record<string, unknown>]> = [
    ["role admin", { role: "admin" }],
    ["study minutes", { totalStudyMinutes: 9999 }],
    ["a phone-clock createdAt", { createdAt: new Date() }],
    ["someone else's email", { email: "bob@example.com" }],
    ["a 1-letter name", { name: "A" }],
    ["a 61-letter name", { name: "x".repeat(61) }],
    ["semester 0", { semester: 0 }],
    ["semester 11", { semester: 11 }],
    ["semester as text", { semester: "3" }],
    ["an unknown field", { isPremium: true }],
  ];
  for (const [label, override] of sneaky) {
    it(`rejects ${label}`, async () => {
      await assertFails(
        db(t.student("alice")).doc(alicePath).set(newProfile(override)),
      );
    });
  }

  it("rejects a profile missing required fields", async () => {
    await assertFails(
      db(t.student("alice")).doc(alicePath).set({ name: "Alice Rao", email: "alice@example.com" }),
    );
  });
});

describe("users: read", () => {
  it("owner can read own profile", async () => {
    await t.seed(alicePath, storedProfile);
    await assertSucceeds(db(t.student("alice")).doc(alicePath).get());
  });

  it("another student cannot read it", async () => {
    await t.seed(alicePath, storedProfile);
    await assertFails(db(t.student("bob")).doc(alicePath).get());
  });

  it("guest cannot read it", async () => {
    await t.seed(alicePath, storedProfile);
    await assertFails(db(t.guest()).doc(alicePath).get());
  });

  it("admin can read any profile and list all users", async () => {
    await t.seed(alicePath, storedProfile);
    await assertSucceeds(db(t.admin()).doc(alicePath).get());
    await assertSucceeds(db(t.admin()).collection("users").limit(20).get());
  });

  it("a student cannot list users", async () => {
    await assertFails(db(t.student("alice")).collection("users").limit(20).get());
  });
});

describe("users: update", () => {
  const update = async (who: string, changes: Record<string, unknown>) => {
    await t.seed(alicePath, storedProfile);
    return db(t.student(who)).doc(alicePath).update(changes);
  };

  it("owner can edit name, photo, university and semester", async () => {
    await assertSucceeds(
      update("alice", {
        name: "Alice R.",
        photoUrl: "https://x/p.jpg",
        universityId: "mu",
        semester: 5,
      }),
    );
  });

  it("owner can record last login with the server clock", async () => {
    await assertSucceeds(update("alice", { lastLoginAt: serverTimestamp() }));
  });

  const locked: Array<[string, Record<string, unknown>]> = [
    ["role", { role: "admin" }],
    ["email", { email: "new@example.com" }],
    ["totalStudyMinutes", { totalStudyMinutes: 500 }],
    ["createdAt", { createdAt: new Date() }],
    ["lastLoginAt with a phone clock", { lastLoginAt: new Date() }],
    ["a new unknown field", { isPremium: true }],
    ["an invalid name", { name: "" }],
    ["semester 42", { semester: 42 }],
  ];
  for (const [label, changes] of locked) {
    it(`owner cannot change ${label}`, async () => {
      await assertFails(update("alice", changes));
    });
  }

  it("another student cannot update it", async () => {
    await assertFails(update("bob", { name: "Hacked" }));
  });

  it("admin cannot write profiles directly (Functions only)", async () => {
    await t.seed(alicePath, storedProfile);
    await assertFails(db(t.admin()).doc(alicePath).update({ name: "Changed" }));
  });
});

describe("users: delete", () => {
  it("nobody can delete a profile from the app", async () => {
    await t.seed(alicePath, storedProfile);
    await assertFails(db(t.student("alice")).doc(alicePath).delete());
    await assertFails(db(t.admin()).doc(alicePath).delete());
  });
});

describe("users/{uid}/entitlements", () => {
  const ent = "users/alice/entitlements/note1";
  const entitlement = { noteId: "note1", orderId: "o1", pricePaid: 4900 };

  it("owner and admin can read", async () => {
    await t.seed(ent, entitlement);
    await assertSucceeds(db(t.student("alice")).doc(ent).get());
    await assertSucceeds(db(t.admin()).doc(ent).get());
    await assertSucceeds(
      db(t.student("alice")).collection("users/alice/entitlements").get(),
    );
  });

  it("another student and guest cannot read", async () => {
    await t.seed(ent, entitlement);
    await assertFails(db(t.student("bob")).doc(ent).get());
    await assertFails(db(t.guest()).doc(ent).get());
  });

  it("NOBODY can write an entitlement from the app (no free notes)", async () => {
    await assertFails(db(t.student("alice")).doc(ent).set(entitlement));
    await assertFails(db(t.admin()).doc(ent).set(entitlement));
    await t.seed(ent, entitlement);
    await assertFails(db(t.student("alice")).doc(ent).delete());
  });
});
