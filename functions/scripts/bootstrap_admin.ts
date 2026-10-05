/**
 * ONE-TIME: make the first admin (nobody can call setAdminClaim yet).
 *
 * The person must already have signed up in the app.
 *
 *   Emulators (safe, for testing):
 *     npm run bootstrap-admin -- you@example.com --emulator
 *
 *   Real project (needs a service-account key — see README; NEVER commit it):
 *     $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\Users\you\.secrets\prepnotes-sa.json"
 *     npm run bootstrap-admin -- you@example.com
 *
 * Add `--remove` to take admin away instead.
 */
import { initializeApp } from "firebase-admin/app";

const PROJECT_ID = "prepnotes-635d6";

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const email = args.find((a) => !a.startsWith("--"));
  const useEmulator = args.includes("--emulator");
  const remove = args.includes("--remove");

  if (!email) {
    console.error("Usage: npm run bootstrap-admin -- <email> [--emulator] [--remove]");
    process.exit(1);
  }

  if (useEmulator) {
    process.env.FIREBASE_AUTH_EMULATOR_HOST ??= "127.0.0.1:9099";
    process.env.FIRESTORE_EMULATOR_HOST ??= "127.0.0.1:8080";
  } else if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    console.error(
      "Set GOOGLE_APPLICATION_CREDENTIALS to your service-account key file first " +
        "(or pass --emulator).",
    );
    process.exit(1);
  }

  initializeApp({ projectId: PROJECT_ID });
  // Imported after initializeApp so it reuses this app.
  const { findUserByEmail, setAdmin } = await import("../src/admin/admin_claims");

  const user = await findUserByEmail(email);
  await setAdmin(user.uid, !remove);

  console.log(
    `${remove ? "Removed admin from" : "Granted admin to"} ${user.email} ` +
      `(uid ${user.uid}) on ${useEmulator ? "the EMULATOR" : PROJECT_ID}.`,
  );
  console.log("They'll get it on next app start, or immediately after re-login.");
}

main().catch((err: unknown) => {
  console.error("Failed:", err instanceof Error ? err.message : err);
  process.exit(1);
});
