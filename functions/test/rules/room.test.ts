/**
 * Phase 6 rules: semester bundles, Resource Room items + uploads (only
 * while the Room is open), Room subscriptions, public config, semester
 * bundle price.
 */
import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { beforeEach, describe, it } from "vitest";
import { serverTimestamp, setupRulesEnv } from "./helpers";

const t = setupRulesEnv();
const DAY = 86_400_000;
const future = () => new Date(Date.now() + 30 * DAY);
const past = () => new Date(Date.now() - DAY);

const link = (o: Record<string, unknown> = {}) => ({
  type: "youtube",
  title: "DBMS lecture",
  url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
  createdAt: serverTimestamp(),
  searchKeywords: ["db", "dbms"],
  ...o,
});

const fileItem = (o: Record<string, unknown> = {}) => ({
  type: "file",
  title: "Class notes",
  fileName: "notes.pdf",
  storagePath: "room/alice/i1/notes.pdf",
  contentType: "application/pdf",
  sizeBytes: 1000,
  createdAt: serverTimestamp(),
  searchKeywords: ["class"],
  ...o,
});

const items = (uid: string) => `users/${uid}/roomItems`;

beforeEach(async () => {
  await t.seed("users/alice", { name: "Alice", email: "alice@example.com", roomAccessUntil: future() });
  await t.seed("users/bob", { name: "Bob", email: "bob@example.com", roomAccessUntil: past() });
  await t.seed("users/carol", { name: "Carol", email: "carol@example.com" });
});

describe("bundles", () => {
  it("owner reads; nobody writes from the app", async () => {
    await t.seed("users/alice/bundles/s3", { expiresAt: future() });
    await assertSucceeds(t.student("alice").firestore().doc("users/alice/bundles/s3").get());
    await assertFails(t.student("bob").firestore().doc("users/alice/bundles/s3").get());
    await assertFails(
      t.student("bob").firestore().doc("users/bob/bundles/s3").set({ expiresAt: future() }),
    );
    await assertFails(t.admin().firestore().doc("users/bob/bundles/s3").set({ x: 1 }));
  });
});

describe("Room items", () => {
  it("open Room: save Drive / YouTube links and files", async () => {
    const db = t.student("alice").firestore();
    await assertSucceeds(db.collection(items("alice")).doc("a").set(link()));
    await assertSucceeds(
      db.collection(items("alice")).doc("b").set(
        link({ type: "drive", url: "https://drive.google.com/file/d/x/view" }),
      ),
    );
    await assertSucceeds(db.collection(items("alice")).doc("i1").set(fileItem()));
    await assertSucceeds(db.collection(items("alice")).get());
  });

  it("closed or never-opened Room: nothing", async () => {
    for (const uid of ["bob", "carol"]) {
      const db = t.student(uid).firestore();
      await assertFails(db.collection(items(uid)).doc("a").set(link()));
      await assertFails(db.collection(items(uid)).get());
    }
  });

  it("other links, bad files and extra fields are refused", async () => {
    const col = t.student("alice").firestore().collection(items("alice"));
    const bad: Array<Record<string, unknown>> = [
      link({ url: "https://evil.com/watch?v=x" }),
      link({ type: "drive", url: "https://drive.google.com.evil.com/x" }),
      link({ type: "drive", url: "http://drive.google.com/file/d/x" }),
      link({ title: "" }),
      link({ isAdmin: true }),
      link({ createdAt: new Date() }),
      fileItem({ storagePath: "room/bob/i1/notes.pdf" }),
      fileItem({ sizeBytes: 30 * 1024 * 1024 }),
      fileItem({ contentType: "application/zip" }),
      fileItem({ url: "https://x.com" }),
    ];
    for (const [i, data] of bad.entries()) {
      await assertFails(col.doc(i === 6 || i > 6 ? "i1" : `x${i}`).set(data));
    }
  });

  it("owner can rename; nobody else can read or write; delete always allowed", async () => {
    await t.seed(`${items("alice")}/a`, { ...link(), createdAt: new Date() });
    const alice = t.student("alice").firestore();
    await assertSucceeds(
      alice.doc(`${items("alice")}/a`).update({ title: "Renamed", searchKeywords: ["re"] }),
    );
    await assertFails(
      alice.doc(`${items("alice")}/a`).update({ url: "https://youtu.be/other00000" }),
    );
    await assertFails(t.student("bob").firestore().doc(`${items("alice")}/a`).get());
    await assertFails(t.admin().firestore().doc(`${items("alice")}/a`).get());

    await t.seed(`${items("bob")}/old`, { ...link(), createdAt: new Date() });
    await assertSucceeds(t.student("bob").firestore().doc(`${items("bob")}/old`).delete());
  });

  it("nobody can give themselves Room access", async () => {
    await assertFails(
      t.student("carol").firestore().doc("users/carol").update({ roomAccessUntil: future() }),
    );
  });
});

describe("subscriptions + config", () => {
  beforeEach(async () => {
    await t.seed("subscriptions/sub_a", { userId: "alice", status: "active" });
    await t.seed("config/roomPlans", { m1: { price: 14900 } });
  });

  it("own subscription readable; nothing writable", async () => {
    const alice = t.student("alice").firestore();
    await assertSucceeds(alice.doc("subscriptions/sub_a").get());
    await assertSucceeds(alice.collection("subscriptions").where("userId", "==", "alice").get());
    await assertFails(t.student("bob").firestore().doc("subscriptions/sub_a").get());
    await assertFails(alice.doc("subscriptions/sub_a").update({ status: "active" }));
    await assertFails(alice.doc("subscriptions/new").set({ userId: "alice" }));
  });

  it("plan prices are public; only Cloud Functions change them", async () => {
    await assertSucceeds(t.guest().firestore().doc("config/roomPlans").get());
    await assertFails(t.admin().firestore().doc("config/roomPlans").set({ m1: { price: 1 } }));
  });
});

describe("semester bundle price", () => {
  const sem = (o: Record<string, unknown> = {}) => ({
    universityId: "mu", number: 3, name: "Semester 3", isActive: true, ...o,
  });

  it("admins may set ₹1 – ₹1,00,000 in paise, or leave it out", async () => {
    const db = t.admin().firestore();
    await assertSucceeds(db.doc("semesters/s3").set(sem()));
    await assertSucceeds(db.doc("semesters/s3").set(sem({ bundlePrice: 89900 })));
    await assertFails(db.doc("semesters/s3").set(sem({ bundlePrice: 50 })));
    await assertFails(db.doc("semesters/s3").set(sem({ bundlePrice: 899.5 })));
    await assertFails(t.student("alice").firestore().doc("semesters/s9").set(sem()));
  });
});

describe("Storage: room/{uid}/{itemId}/{file}", () => {
  const pdf = { contentType: "application/pdf" };
  const small = new Uint8Array(1024);

  beforeEach(async () => {
    await t.seed(`${items("alice")}/i1`, { type: "file" });
    await t.seed(`${items("bob")}/i1`, { type: "file" });
  });

  it("owner with an open Room uploads for an existing item and reads it back", async () => {
    const r = t.student("alice").storage().ref("room/alice/i1/notes.pdf");
    await assertSucceeds(r.put(small, pdf));
    await assertSucceeds(r.getDownloadURL());
    await assertSucceeds(r.delete());
  });

  it("no item doc, wrong type, too big, someone else's, or Room closed → refused", async () => {
    const alice = t.student("alice").storage();
    await assertFails(alice.ref("room/alice/nope/notes.pdf").put(small, pdf));
    await assertFails(alice.ref("room/alice/i1/a.zip").put(small, { contentType: "application/zip" }));
    await assertFails(alice.ref("room/alice/i1/big.pdf").put(new Uint8Array(25 * 1024 * 1024 + 1), pdf));
    await assertFails(t.student("bob").storage().ref("room/alice/i1/x.pdf").put(small, pdf));
    await assertFails(t.student("bob").storage().ref("room/bob/i1/x.pdf").put(small, pdf));
    await assertFails(t.admin().storage().ref("room/alice/i1/x.pdf").put(small, pdf));
  });
});
