# PrepNotes

University-wise notes (University → Semester → Subject → Module → Notes), a free
Resource Room, Study Zone (Pomodoro / Stopwatch), Student Voice and an Admin
Panel — one Flutter codebase for **Web, Android and iOS**, backed by **Firebase**.

- Project rules for contributors and AI agents: [`CLAUDE.md`](CLAUDE.md)
- Full plan, data model and phases: [`docs/PrepNotes_Implementation_Plan.md`](docs/PrepNotes_Implementation_Plan.md)

| | |
|---|---|
| Firebase project | `prepnotes-635d6` (region `asia-south1`, Mumbai) |
| App ID (Android / iOS) | `com.prepnotes.prepnotes` |
| Status | Phase 5 done — admin dashboard (live stats + 30-day revenue), users (search, disable, admin), orders (filters, refunds, CSV). |
| Legal text | `lib/features/legal/domain/legal_content.dart` — a template; set `LegalInfo.operatorName` to your KYC name |

---

## Tech stack

| Layer | Choice |
|---|---|
| App | Flutter 3.47+ (Dart 3.13+), Material 3 via `package:material_ui` |
| State | Riverpod 3 with code generation |
| Navigation | go_router (clean web URLs, auth/admin guards) |
| Models | freezed + json_serializable |
| Backend | Firebase Auth, Firestore, Storage, Hosting, App Check |
| Server code | Cloud Functions 2nd gen, TypeScript, Node 22 |
| Payments | Razorpay (INR) — all verification on the server |

Money is always stored as an **integer in paise** (₹49 = `4900`).

---

## 1. One-time setup

Install:

| Tool | Check with | Notes |
|---|---|---|
| Flutter (stable, 3.47+) | `flutter --version` | `flutter upgrade` to update |
| Node.js 22+ | `node --version` | Functions deploy on Node 22 |
| Firebase CLI | `firebase --version` | `npm i -g firebase-tools` |
| FlutterFire CLI | `flutterfire --version` | `dart pub global activate flutterfire_cli` |
| Java 21+ | `java -version` | Needed by the Firestore/Storage emulators |
| Android Studio + SDK | `flutter doctor` | For Android builds |

Then, in the project root:

```bash
firebase login                      # account that owns prepnotes-635d6
flutter pub get
dart run build_runner build         # generates *.g.dart / *.freezed.dart (not in git)
cd functions && npm install && cd ..
```

> **Generated files are not committed.** If VS Code shows
> "Target of URI hasn't been generated", run `dart run build_runner build`.
> While coding you can keep `dart run build_runner watch` running instead.

---

## 2. Run the app

### Web (Chrome)

```bash
flutter run -d chrome
```

### Android (your phone)

1. Phone: **Settings → About phone →** tap **Build number** 7×, then
   **Developer options → USB debugging ON** (Xiaomi: also *Install via USB*).
2. Connect with a USB **data** cable and tap **Allow** on the phone.
3. Check it's listed, then run:

```bash
flutter devices
flutter run            # pick your phone if asked
```

Press `r` for hot reload, `R` for hot restart, `q` to quit.

### iOS

Requires a Mac with Xcode. Firebase is initialised from `lib/firebase_options.dart`.

---

## 3. Firebase Emulators (local, free, safe)

```bash
flutter build web          # Hosting emulator serves build/web
firebase emulators:start   # Ctrl + C to stop
```

| Emulator | URL |
|---|---|
| **Emulator UI** | http://localhost:4000 |
| Hosting (the web app) | http://localhost:5000 |
| Functions | http://localhost:5001 — e.g. `/prepnotes-635d6/asia-south1/healthCheck` |
| Firestore | localhost:8080 |
| Auth | localhost:9099 |
| Storage | localhost:9199 |

---

## 4. Tests and checks

```bash
# Flutter
dart format .
flutter analyze
flutter test

# Cloud Functions
cd functions
npm run lint
npm run build
npm run rules:test     # security-rules tests
npm run test:all       # rules + Cloud Functions tests
cd ..
```

> These start their own emulators on separate ports (`firebase.test.json`),
> so they're safe to run while your `firebase emulators:start` is running.

---

## 5. Deploy

```bash
firebase deploy --only firestore:rules     # database security rules
firebase deploy --only storage             # storage rules

flutter build web
firebase deploy --only hosting             # the website

firebase deploy --only functions           # server code (needs Blaze plan)
```

---

## 6. Admins

Admin = the Firebase Auth custom claim `admin: true` (set only on the server).

**Sample data (catalog + 5 notes with PDFs):**

```bash
npm --prefix functions run seed -- --emulator     # emulators (start them first)
# Real project: set GOOGLE_APPLICATION_CREDENTIALS (see below), then
npm --prefix functions run seed
```

**Owner (automatic).** Emails in `OWNER_EMAILS` (`functions/src/config.ts`)
become admin by themselves: sign in with that account (Google, or
email/password after clicking the verification link) and the
`onUserProfileWritten` function grants admin within seconds. The app refreshes
its token automatically, so `/admin` opens without a restart.
Needs the functions deployed: `firebase deploy --only functions`.

**Backup script** (emulators, or emergencies). Sign up in the app first, then:

```bash
# Emulators
npm --prefix functions run bootstrap-admin -- you@example.com --emulator

# Real project — needs a service-account key (Console → Project settings →
# Service accounts → Generate new private key). Save it OUTSIDE the repo.
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\Users\<you>\.secrets\prepnotes-sa.json"
npm --prefix functions run bootstrap-admin -- you@example.com
```

Add `--remove` to take admin away. The app picks up the change on its next
start (it refreshes the token once per launch) or right after re-login.

**More admins:** Admin → Users → open the person → *Make admin* (calls the
`setAdminClaim` function). Admins can't remove their own access.

---

## 6b. Payments (Razorpay)

**Who can buy where:** the **website** has Razorpay Checkout. The **Android/iOS
app** shows *Buy on website* (Play Store / App Store rules for digital goods)
and opens everything the student bought. To allow in-app buying later, add
`razorpay_flutter` and change `buyInApp` in
`lib/features/purchases/data/payment_service.dart`.

**Flow:** `createOrder` (server reads the price) → Razorpay Checkout →
`verifyPayment` (server checks the signature) → entitlement written by the
server. `razorpayWebhook` does the same if the tab was closed. Both are
idempotent. PDFs open only through `getNoteFileUrl` (10-minute signed link).

### Keys (test mode first)

Razorpay Dashboard → switch to **Test Mode** → Account & Settings → **API Keys**
→ Generate. Never commit or paste the Key Secret anywhere except these prompts:

```bash
firebase functions:secrets:set RAZORPAY_KEY_ID          # rzp_test_…
firebase functions:secrets:set RAZORPAY_KEY_SECRET
firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET  # any long random text you choose
```

For the emulators, create `functions/.secret.local` (git-ignored):

```
RAZORPAY_KEY_ID=rzp_test_xxx
RAZORPAY_KEY_SECRET=xxx
RAZORPAY_WEBHOOK_SECRET=xxx
```

### Signed PDF links (one-time, production)

The functions' service account must be allowed to sign URLs:
Google Cloud Console → IAM → find `PROJECT_NUMBER-compute@developer.gserviceaccount.com`
→ Edit → **Add role: Service Account Token Creator** → Save. (Also enable the
*IAM Service Account Credentials API* if asked.) Without it, "Read now" fails
with an internal error.

### Webhook

After `firebase deploy --only functions`, copy the `razorpayWebhook` URL from
the output. Razorpay Dashboard (Test Mode) → Account & Settings → **Webhooks**
→ Add: that URL, the same secret as `RAZORPAY_WEBHOOK_SECRET`, events
**payment.captured**, **payment.failed**, **order.paid**.

### Test payments

Use Razorpay's test details (Razorpay docs → *Test card / UPI details*), e.g.
UPI ID `success@razorpay` (succeeds) or `failure@razorpay` (fails). Test-mode
money is not real.

### Refunds

Refunds are **recorded** in the app, not sent from it:
1. Razorpay Dashboard → Transactions → Payments → the payment → **Issue refund**.
2. PrepNotes Admin → Orders → the order → **Mark as refunded** (optional reason).
   The student loses access to that note and the dashboard numbers go down.

### Dashboard numbers

`stats/global` and `stats_daily/{day}` are kept up to date by Cloud Functions
(new students, published notes, payments, refunds). Admin → Dashboard →
**Recalculate stats** rebuilds them from the real data (run it once after the
first deploy of Phase 5 — it also fills in the search name for old accounts).

### Going live (after the website is approved)

Switch the dashboard to Live Mode, generate live keys, run the three
`secrets:set` commands again with the live values, add the webhook again in
Live Mode, and `firebase deploy --only functions`.

---

## 7. Project structure

```
lib/
  main.dart            start-up: error zone, Firebase, Crashlytics, ProviderScope
  app.dart             MaterialApp.router (theme + router)
  firebase_options.dart  generated by `flutterfire configure`
  core/
    constants/         app_strings, firestore_paths, storage_paths
    errors/            ErrorReporter (Crashlytics on mobile, console on web)
    router/            routes, paths, auth/admin guards
    theme/             colours, typography, light/dark Material 3 theme
    utils/             responsive helper (mobile <600, tablet 600–1024, desktop >1024)
    widgets/           AppScaffold, AppLogo, placeholder + 404 screens
  data/                shared models + repositories
  features/<feature>/{presentation,domain,data}
    auth, home, notes, purchases, study_zone, resource_room,
    student_voice, profile, search, admin
functions/             Cloud Functions (TypeScript) + security-rules tests
firestore.rules        Firestore security rules
storage.rules          Storage security rules
firebase.json          Hosting, rules, functions, emulator config
```

---

## 8. Security essentials

- Clients can **never** write `orders` or `users/{uid}/entitlements` — only Cloud Functions.
- Private PDFs (`notes_private/…`) are served only via a short-lived signed URL
  from a Cloud Function after an entitlement check.
- Admin = Firebase Auth custom claim `admin: true`, enforced in rules and every admin Function.
- **Never commit secrets.** Use `firebase functions:secrets:set NAME` for server
  secrets. `.env`, keystores and service-account files are git-ignored.
- `lib/firebase_options.dart` and `google-services.json` are **not secrets** — they
  only identify the project; security comes from rules and App Check.

---

## 9. Troubleshooting

| Problem | Fix |
|---|---|
| `Target of URI hasn't been generated` | `dart run build_runner build` |
| Android build: *Could not close incremental caches* | Already handled by `kotlin.incremental=false` in `android/gradle.properties` (project and pub cache on different drives). Run `flutter clean` once. |
| Emulators: *port taken* | Another emulator is running — stop it (Ctrl + C) or close the process using the port. |
| Emulators: *Java not found* | Install Java 21+ and restart the terminal. |
| `flutter devices` doesn't show the phone | Use a data cable, set USB mode to *File transfer*, re-accept the debugging prompt. |
| "Read now" says something went wrong (production) | Give the functions service account the *Service Account Token Creator* role (§6b). |
| Checkout says the payment service is busy | Secrets missing or wrong (`firebase functions:secrets:access RAZORPAY_KEY_ID`), or an ad-blocker blocked `checkout.razorpay.com`. |
| Functions emulator warns Node 22 vs 24 | Harmless locally; Google runs Node 22 when deployed. |
