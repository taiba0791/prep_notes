/**
 * Storage rules: avatars (Phase 1). Everything else stays locked.
 */
import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { describe, it } from "vitest";
import { setupRulesEnv } from "./helpers";

const t = setupRulesEnv();

const jpeg = { contentType: "image/jpeg" };
const smallImage = new Uint8Array(10 * 1024); // 10 KB
const tooBig = new Uint8Array(2 * 1024 * 1024 + 1); // just over 2 MB

const ref = (ctx: ReturnType<typeof t.guest>, path: string) =>
  ctx.storage().ref(path);

describe("avatars/{uid}/avatar.jpg", () => {
  const path = "avatars/alice/avatar.jpg";

  it("owner can upload a small image", async () => {
    await assertSucceeds(ref(t.student("alice"), path).put(smallImage, jpeg));
  });

  it("owner cannot upload more than 2 MB", async () => {
    await assertFails(ref(t.student("alice"), path).put(tooBig, jpeg));
  });

  it("owner cannot upload a non-image", async () => {
    await assertFails(
      ref(t.student("alice"), path).put(smallImage, { contentType: "application/pdf" }),
    );
  });

  it("owner cannot use another file name", async () => {
    await assertFails(
      ref(t.student("alice"), "avatars/alice/evil.jpg").put(smallImage, jpeg),
    );
  });

  it("nobody else can upload to my avatar", async () => {
    await assertFails(ref(t.student("bob"), path).put(smallImage, jpeg));
    await assertFails(ref(t.guest(), path).put(smallImage, jpeg));
    await assertFails(ref(t.admin(), path).put(smallImage, jpeg));
  });

  it("anyone can view an avatar; only the owner can delete it", async () => {
    await t.env().withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage().ref(path).put(smallImage, jpeg);
    });
    await assertSucceeds(ref(t.guest(), path).getDownloadURL());
    await assertFails(ref(t.student("bob"), path).delete());
    await assertSucceeds(ref(t.student("alice"), path).delete());
  });
});

describe("private notes stay locked", () => {
  it("even the uploader/admin can't touch notes_private from the app", async () => {
    await assertFails(
      ref(t.admin(), "notes_private/n1/file.pdf").put(smallImage, {
        contentType: "application/pdf",
      }),
    );
    await assertFails(ref(t.student("alice"), "notes_private/n1/file.pdf").getDownloadURL());
  });
});
