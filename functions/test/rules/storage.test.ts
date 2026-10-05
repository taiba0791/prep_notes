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

describe("notes_private: paid PDFs", () => {
  const pdf = { contentType: "application/pdf" };
  const path = "notes_private/n1/file.pdf";

  it("admins can upload, replace and delete a PDF", async () => {
    await assertSucceeds(ref(t.admin(), path).put(smallImage, pdf));
    await assertSucceeds(ref(t.admin(), path).put(smallImage, pdf));
    await assertSucceeds(ref(t.admin(), path).delete());
  });

  it("NOBODY can read a private PDF from the app — not even admins", async () => {
    await t.env().withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage().ref(path).put(smallImage, pdf);
    });
    await assertFails(ref(t.guest(), path).getDownloadURL());
    await assertFails(ref(t.student("alice"), path).getDownloadURL());
    await assertFails(ref(t.admin(), path).getDownloadURL());
  });

  it("students can't upload; admins can't upload non-PDFs or other names", async () => {
    await assertFails(ref(t.student("alice"), path).put(smallImage, pdf));
    await assertFails(ref(t.admin(), path).put(smallImage, jpeg));
    await assertFails(ref(t.admin(), "notes_private/n1/other.pdf").put(smallImage, pdf));
  });
});

describe("notes_public: thumbnails and previews", () => {
  it("anyone can view; only admins upload thumbnails", async () => {
    const path = "notes_public/n1/thumbnail.jpg";
    await assertSucceeds(ref(t.admin(), path).put(smallImage, jpeg));
    await assertSucceeds(ref(t.guest(), path).getDownloadURL());
    await assertFails(ref(t.student("alice"), path).put(smallImage, jpeg));
    await assertFails(ref(t.admin(), path).put(tooBig, jpeg));
  });

  it("preview.pdf can't be uploaded from the app (Cloud Function makes it)", async () => {
    await assertFails(
      ref(t.admin(), "notes_public/n1/preview.pdf").put(smallImage, {
        contentType: "application/pdf",
      }),
    );
  });
});

describe("university logos", () => {
  it("anyone can view; only admins upload small images", async () => {
    const path = "universities/mu/logo";
    await assertSucceeds(ref(t.admin(), path).put(smallImage, jpeg));
    await assertSucceeds(ref(t.guest(), path).getDownloadURL());
    await assertFails(ref(t.student("alice"), path).put(smallImage, jpeg));
    await assertFails(ref(t.admin(), path).put(tooBig, jpeg));
  });
});
