# PrepNotes — Implementation Plan (Flutter + Firebase)

One Flutter codebase → **Website (Flutter Web)** + **Android app** + **iOS app**, all backed by **Firebase**.

---

## 1. Tech Stack

| Layer | Choice | Why |
|---|---|---|
| UI / Client | **Flutter 3.x (Dart)** | One codebase for web, Android, iOS |
| State management | **Riverpod** (`flutter_riverpod`, `riverpod_annotation`) | Testable, scalable, works well with AI-generated code |
| Routing | **go_router** | Deep links, web URLs, route guards (auth/admin) |
| Auth | **Firebase Authentication** (email/password + Google sign-in) | Required by your feature list |
| Database | **Cloud Firestore** | Hierarchical data, realtime, security rules |
| File storage | **Firebase Storage** | PDFs, thumbnails, resource files, profile pictures |
| Backend logic | **Cloud Functions for Firebase (TypeScript, 2nd gen)** | Payment verification, secure PDF URLs, admin actions, stats |
| Payments | **Razorpay** (recommended for India: UPI, cards, netbanking) | Alternative: Stripe / Cashfree |
| Hosting | **Firebase Hosting** | Serves the Flutter web build |
| Notifications | Firebase Cloud Messaging (FCM) | Optional: purchase confirmations, request updates |
| Analytics / Errors | Firebase Analytics + Crashlytics + Performance | Analytics requirement |
| Abuse protection | **Firebase App Check** | Blocks non-app traffic to Firestore/Storage/Functions |
| PDF viewing | `syncfusion_flutter_pdfviewer` (free community license) or `pdfx` | Works on web + mobile |
| Misc packages | `freezed`, `json_serializable`, `cached_network_image`, `url_launcher`, `file_picker`, `image_picker`, `shared_preferences`, `intl`, `flutter_hooks` (optional) | Models, uploads, links, local storage |
| Tooling | VS Code + **Claude Code extension**, FlutterFire CLI, Firebase CLI, Firebase Emulator Suite, Git + GitHub | |

### Important decisions & caveats (read before starting)

1. **Admin Panel** → build it inside the *same* Flutter app under `/admin/*` routes, shown only to users with an `admin` **custom claim**. Use it on web (desktop-friendly layout). Do not rely on hiding buttons — enforce admin in Firestore/Storage rules and Cloud Functions.
2. **Razorpay on web:** the official Flutter plugin supports Android/iOS only. For web, either use Razorpay Checkout JS through JS interop, or create orders server-side and open a Razorpay hosted checkout. Plan this in Phase 5.
3. **Payment security:** the app must *never* decide a purchase succeeded. Only a Cloud Function (verifying the Razorpay signature / webhook) may write the purchase record.
4. **Secure PDF access:** PDFs live in a private path; clients can never read them directly. A callable Cloud Function checks the purchase and returns a short-lived signed URL. Be aware: nothing can fully stop a paying user from screenshotting or saving a PDF — the goal is to stop *unpaid* access and casual sharing (optionally add a watermark with the buyer's email later).
5. **Search:** Firestore has no full-text search. MVP uses a `searchKeywords` array + prefix queries; later upgrade to Algolia or Typesense (Firebase Extension).
6. **SEO:** Flutter Web is weak for SEO. Mitigation: a lightweight static landing page + correct `<title>`/meta/OpenGraph in `web/index.html`, and a sitemap. If SEO becomes critical, build only the public marketing pages in a separate static site later.
7. **Cost control:** use Firestore pagination everywhere, avoid unbounded listeners, and store aggregate counters (`stats/global`) instead of counting collections on every dashboard load.

---

## 2. Architecture Overview

```
Flutter App (Web / Android / iOS)
   │  Riverpod + go_router + Repository layer
   ▼
Firebase Auth ─── Firestore ─── Storage ─── App Check
                       ▲
                       │ (privileged writes only)
              Cloud Functions (TypeScript)
   createOrder · verifyPayment/webhook · getNoteFileUrl
   setAdminClaim · onUserCreate · aggregate stats · onFeedbackCreate
                       ▲
                       │
                    Razorpay
```

### Folder structure (feature-first, clean layers)

```
prepnotes/
├── CLAUDE.md                     # project rules for Claude Code (see Section 6)
├── lib/
│   ├── main.dart / app.dart
│   ├── core/                     # theme, constants, router, utils, widgets, errors
│   ├── data/                     # models, repositories (Firestore/Storage access)
│   └── features/
│       ├── auth/
│       ├── home/
│       ├── notes/                # browse, detail, viewer
│       ├── purchases/
│       ├── study_zone/           # pomodoro, stopwatch
│       ├── resource_room/
│       ├── student_voice/
│       ├── profile/
│       ├── search/
│       └── admin/                # dashboard, catalog, notes, users, orders, resources, voice
├── functions/                    # Cloud Functions (TypeScript)
├── firestore.rules
├── storage.rules
├── firestore.indexes.json
├── firebase.json
└── test/
```

Each feature: `presentation/` (screens, widgets, controllers) → `domain/` (optional) → `data/` (repositories). UI never calls Firebase directly; only repositories do.

---

## 3. Firestore Data Model

```
users/{uid}
  name, email, photoUrl, universityId, semester, role ('student'|'admin' mirror only),
  totalStudyMinutes, createdAt, lastLoginAt

users/{uid}/entitlements/{noteId}          // written ONLY by Cloud Functions
  noteId, orderId, purchasedAt, pricePaid

users/{uid}/recentlyViewed/{noteId}        // optional
users/{uid}/studySessions/{sessionId}      // type, durationSec, startedAt

universities/{universityId}
  name, shortName, city, logoUrl, description, isActive, order

semesters/{semesterId}
  universityId, number, name, isActive

subjects/{subjectId}
  universityId, semesterId, name, code, description, isActive

modules/{moduleId}
  subjectId, number, title, isActive

notes/{noteId}
  title, description, universityId, semesterId, subjectId, moduleId,
  universityName, subjectName, moduleTitle,            // denormalized for list screens
  price (INR, integer paise or rupees — pick one and document), isFree,
  thumbnailUrl, pageCount, fileSizeBytes,
  storagePath (private),  previewPages (int, free preview),
  isPublished, purchaseCount, tags[], searchKeywords[],
  createdAt, updatedAt

orders/{orderId}                           // written ONLY by Cloud Functions
  userId, noteIds[], amount, currency, status ('created'|'paid'|'failed'|'refunded'),
  razorpayOrderId, razorpayPaymentId, createdAt, paidAt, failureReason

resourceCategories/{categoryId}   name, icon, order
resources/{resourceId}
  title, description, categoryId, type ('link'|'file'), url / storagePath,
  tags[], isActive, createdAt

feedback/{feedbackId}
  type ('feature_problem'|'notes_request'|'general'),
  subType ('feature_request'|'bug'|'subject_notes'|'module'|'papers'|'university_notes'|'new_university'|...),
  title, message, userId, userEmail, universityRef?, subjectName?, moduleName?,
  status ('new'|'reviewed'|'resolved'|'rejected'), adminNote, createdAt, updatedAt

stats/global
  totalStudents, totalNotes, totalPurchases, totalRevenue   // maintained by Functions
```

**Storage layout**
```
notes_private/{noteId}/file.pdf        # no client read access
notes_public/{noteId}/thumbnail.jpg    # public read
notes_public/{noteId}/preview.pdf      # optional free preview pages
resources/{resourceId}/{filename}      # public read, admin write
avatars/{uid}/avatar.jpg               # owner write, public read
```

---

## 4. Security Rules Summary (build alongside each phase)

- `admin` = `request.auth.token.admin == true` (custom claim set by a Function).
- Public catalog (universities, semesters, subjects, modules, published notes, resources): **read = anyone** (or signed-in), **write = admin only**.
- `users/{uid}`: owner can read/update **except** `role`, `totalStudyMinutes` tampering is acceptable but note it; admin can read all.
- `entitlements` and `orders`: **read = owner or admin; write = never from client**.
- `feedback`: signed-in users can **create** (with field validation and own `userId`) and read their own; admin read/update/delete all; users cannot change `status`.
- Storage: `notes_private/**` → `allow read, write: if false` (Functions use Admin SDK); other paths per layout above.
- Enable **App Check** enforcement after testing.
- Test every rule with the **Firebase Emulator Suite** (`@firebase/rules-unit-testing`).

---

## 5. Phases (recommended order)

| Phase | Name | Outcome | Est. time* |
|---|---|---|---|
| 0 | Foundation & setup | Project runs on web + mobile, Firebase connected, theme, router | 2–3 days |
| 1 | Authentication & Profile | Register/login/reset, protected routes, profile, admin claim | 4–5 days |
| 2 | Catalog data + Admin content management | Admin can create University→Semester→Subject→Module and upload notes | 6–8 days |
| 3 | Student Notes browsing & preview | Home, browse hierarchy, note details, free preview, basic search | 6–8 days |
| 4 | Payments, Purchases & secure PDF | Checkout, verification, My Purchases, protected PDF viewer | 7–10 days |
| 5 | Admin Dashboard, Users & Orders | Stats, user list, order management | 4–5 days |
| 6 | Resource Room | Public resources + admin management | 4–5 days |
| 7 | Student Voice | 3 feedback sections + admin tabs | 4–5 days |
| 8 | Study Zone | Pomodoro, stopwatch, session tracking, stats | 3–4 days |
| 9 | Global Search, Polish & Responsiveness | Global search, 404, empty/loading states, SEO, analytics | 4–6 days |
| 10 | Testing, Hardening & Release | Rules tests, App Check, performance, store + hosting deploy | 5–7 days |

\*Rough estimates for one developer working with Claude Code. Treat as ballparks.

**Golden rules while working with the AI agent**
1. One phase = one git branch. Commit after every working sub-task.
2. Start each phase in **Plan Mode** (or ask the agent to "propose a plan first, don't write code yet"). Approve the plan, then let it implement.
3. Always ask the agent to **run `flutter analyze` and fix issues**, and to run the app/emulators when possible.
4. Never paste secrets (Razorpay key *secret*, service accounts) into prompts. Use Firebase Functions secrets (`firebase functions:secrets:set`).
5. If the agent drifts, point it back to `CLAUDE.md` and the data model in this document.

---

## 6. `CLAUDE.md` (put this in your project root FIRST)

Create a file named `CLAUDE.md` in the repo root and paste this. Claude Code reads it automatically every session.

```markdown
# PrepNotes — Project Rules

## What this is
PrepNotes: a student platform to browse/buy university-wise notes (University → Semester → Subject → Module → Notes),
free Resource Room, Study Zone (Pomodoro/Stopwatch), Student Voice (feedback), Profile, and an Admin Panel.
Targets: Flutter Web + Android + iOS. Backend: Firebase (Auth, Firestore, Storage, Functions, Hosting, App Check).

## Stack
- Flutter (latest stable), Dart null-safety, Riverpod (with code generation), go_router, freezed + json_serializable.
- Cloud Functions in TypeScript (2nd gen), Node 20.
- Payments: Razorpay (INR). Server verifies everything.

## Architecture rules
- Feature-first folders: lib/features/<feature>/{presentation,data,domain}. Shared code in lib/core and lib/data.
- UI widgets NEVER call Firebase directly. Use repositories exposed via Riverpod providers.
- Models are immutable (freezed). No business logic in widgets.
- All Firestore collection/field names live in lib/core/constants/firestore_paths.dart. No magic strings.
- Every screen must handle: loading, error, empty, and data states.
- Responsive: mobile (<600), tablet (600–1024), desktop (>1024). Use a shared responsive helper; no hard-coded pixel layouts.
- Paginate all lists (limit + startAfter). No unbounded Firestore listeners.
- Use Material 3 with a central theme (light + dark). No hard-coded colors in widgets.
- User-facing strings in one place so they can be localized later.

## Security rules (non-negotiable)
- Clients can NEVER write to `orders` or `users/{uid}/entitlements`. Only Cloud Functions do.
- Private PDFs are served only through a callable Function returning a short-lived signed URL after entitlement check.
- Admin = custom claim `admin: true`. Enforce in firestore.rules, storage.rules and in every admin Function.
- Never commit secrets. Use Functions secrets / .env files ignored by git.

## Workflow rules
- Before coding a phase: write a short plan and list the files you will create/change. Wait for approval.
- After coding: run `flutter analyze`, `dart format .`, relevant tests, and fix all issues.
- Keep commits small, with conventional commit messages.
- When unsure about a requirement, ask instead of guessing.
- Do not add packages without stating why.

## Definition of done (per feature)
Works on web + mobile layout, handles loading/error/empty states, rules updated + tested in emulator, no analyzer warnings.
```

---

## 7. Phase-by-Phase Prompts for Claude Code

> **How to use:** Open the project folder in VS Code → open Claude Code → paste the prompt. Replace `[ ]` placeholders. Where it says "attach", reference this file: `@PrepNotes_Implementation_Plan.md` (and your original feature list file) so the agent has the data model.

---

### Pre-phase (manual steps you do yourself)

1. Install: Flutter SDK, Node 20+, Firebase CLI (`npm i -g firebase-tools`), FlutterFire CLI (`dart pub global activate flutterfire_cli`), Git.
2. Create a Firebase project (console.firebase.google.com). Upgrade to **Blaze** plan (required for Cloud Functions; free quota still applies).
3. Enable: Authentication (Email/Password, Google), Firestore, Storage, Hosting.
4. Create a GitHub repo.
5. Create an empty folder `prepnotes`, add `CLAUDE.md` (Section 6) and copy this plan + your feature list into a `/docs` folder.

---

### PHASE 0 — Foundation & Setup

```
Read CLAUDE.md and docs/PrepNotes_Implementation_Plan.md fully.

Goal: set up the PrepNotes project foundation. Do NOT build any features yet.

First, give me a short plan. Then, after I approve, do the following:

1. Create a Flutter project in the current folder (org: com.prepnotes, name: prepnotes) with platforms: web, android, ios.
2. Add dependencies: flutter_riverpod, riverpod_annotation, riverpod_generator, build_runner, go_router, freezed, freezed_annotation, json_serializable, firebase_core, firebase_auth, cloud_firestore, firebase_storage, cloud_functions, firebase_analytics, firebase_crashlytics (non-web), firebase_app_check, google_fonts, cached_network_image, url_launcher, intl, shared_preferences. Explain anything extra you want to add.
3. Set up the feature-first folder structure from the plan.
4. Create Material 3 theme (light + dark) in lib/core/theme with a clean student-friendly look (propose a color palette in your plan).
5. Create a responsive helper (breakpoints mobile/tablet/desktop) and a reusable AppScaffold that shows a bottom nav bar on mobile and a top nav/side rail on desktop with placeholders for: Home, Notes, Study Zone, Resources, Student Voice, Profile.
6. Set up go_router with placeholder screens for every route in the app (including /admin/* and a 404 NotFound screen) and a structure ready for auth guards.
7. Create lib/core/constants/firestore_paths.dart with all collection names from the data model in the plan.
8. Initialize Firebase using FlutterFire CLI instructions (tell me the exact commands to run if you can't run them yourself). Set up main.dart with Firebase init, ProviderScope, error handling zone, and Crashlytics where supported.
9. Initialize firebase.json for Hosting (Flutter web build output), Firestore, Storage, Functions (TypeScript), and Emulators. Create a functions/ folder with a TypeScript skeleton.
10. Add basic firestore.rules and storage.rules that deny everything by default for now.
11. Add .gitignore entries for secrets and generated files, and a README with run instructions (web, android, emulators).

Finish by running `flutter analyze` and `flutter run -d chrome` (or tell me how to) and confirm the app launches with the navigation shell.
```

---

### PHASE 1 — Authentication & Profile

```
Read CLAUDE.md and the data model in docs/PrepNotes_Implementation_Plan.md.

Goal: implement Phase 1 — Authentication & Profile. Plan first, wait for approval, then build.

Requirements:
1. AuthRepository (FirebaseAuth): register (name, email, password), login, Google sign-in, logout, forgot password (email reset), delete account (optional), auth state stream. Expose via Riverpod providers.
2. On registration create `users/{uid}` document (name, email, photoUrl, universityId, semester, createdAt). Use a Cloud Function `onUserCreate` trigger OR client write — choose the safer option and explain.
3. Screens: Login, Register, Forgot Password, with form validation, loading states, friendly error messages. Responsive (centered card on desktop).
4. go_router guards: unauthenticated users can browse public pages but are redirected to Login for protected pages (My Purchases, Profile, Student Voice submission). Redirect back to the intended page after login.
5. Admin support: create a callable Cloud Function `setAdminClaim` (callable only by an existing admin, plus a documented one-time script to bootstrap the first admin by email using the Admin SDK). Add an `adminGuard` to go_router for /admin/* that checks the custom claim from the ID token (force-refresh token after claim change).
6. Profile screen: view/edit name, profile picture (upload to avatars/{uid}), university (dropdown – load from `universities` if present, otherwise allow empty), semester; Change password (re-auth required); Logout. Show placeholders for "Total purchases", "Study time", "Recently viewed" to be filled in later.
7. Update firestore.rules and storage.rules for `users` and `avatars` per the Security Rules Summary. Write emulator-based rule tests for these.
8. Unit/widget tests for form validation and auth controller.

When done: run analyze + tests, and give me a manual test checklist (register, login, logout, reset password, admin claim bootstrap).
```

---

### PHASE 2 — Catalog Data + Admin Content Management

```
Read CLAUDE.md and docs/PrepNotes_Implementation_Plan.md (sections 3 and 4).

Goal: implement Phase 2 — Admin catalog management and notes upload. Plan first, wait for approval.

Requirements:
1. Admin layout: responsive admin shell at /admin with a side navigation (Dashboard placeholder, Universities, Semesters, Subjects, Modules, Notes, Users (placeholder), Orders (placeholder), Resources (placeholder), Student Voice (placeholder)). Guarded by adminGuard.
2. Models + repositories (freezed) for University, Semester, Subject, Module, Note per the data model.
3. Admin CRUD screens (data table on desktop, cards on mobile) with search, pagination, create/edit dialogs or pages, delete with confirmation dialog, active/inactive toggle:
   - Universities (name, shortName, city, logo upload, description)
   - Semesters (select university → number/name)
   - Subjects (select university → semester → name, code)
   - Modules (select subject → number, title)
   Use cascading dropdowns (University → Semester → Subject).
4. Prevent orphan data: when deleting a university/semester/subject/module, either block if children exist or cascade via a Cloud Function — choose the safer approach and explain it.
5. Notes management screen:
   - Create/edit note: title, description, cascading University → Semester → Subject → Module selectors, price (or isFree), tags, publish/unpublish toggle, thumbnail upload, PDF upload (to notes_private/{noteId}/file.pdf) with upload progress, replace PDF, delete note (also delete files).
   - Auto-fill denormalized names (universityName, subjectName, moduleTitle) and generate `searchKeywords` from title/subject/university/tags.
   - Read PDF page count and file size on upload if feasible (otherwise Cloud Function on storage finalize).
   - Optional free preview: admin sets `previewPages`; a Cloud Function extracts first N pages into notes_public/{noteId}/preview.pdf (propose approach, e.g. pdf-lib).
6. Firestore + Storage rules: public read for catalog (published notes only for non-admin), admin-only writes, notes_private fully locked. Add emulator rule tests.
7. Add composite indexes to firestore.indexes.json for the queries you use.
8. Add a seeding script (functions/scripts or a Dart script) that creates sample data: 2 universities, 2 semesters each, 3 subjects each, 2 modules each, 5 notes (with a dummy PDF) for development.

Finish with analyze + tests + a manual test checklist.
```

---

### PHASE 3 — Student Notes Browsing, Home & Preview

```
Read CLAUDE.md and docs/PrepNotes_Implementation_Plan.md.

Goal: implement Phase 3 — student-facing Home and Notes browsing. Plan first, wait for approval.

Requirements:
1. Home screen: hero section with search bar, Browse by University / Semester / Subject sections, Featured/Popular notes (sort by purchaseCount, or an admin `isFeatured` flag — add it), "Why PrepNotes" section, quick links to Study Zone and Resource Room, testimonials section (static data for now, structured so admin can manage later), Login/Sign up buttons (or avatar when logged in), footer with important links (About, Contact, Privacy, Terms, social).
2. Notes browsing flow with URLs that work on web (deep-linkable):
   /notes → universities → /notes/u/:universityId → semesters → /notes/s/:semesterId → subjects → /notes/sub/:subjectId → modules with their notes → /notes/:noteId (details).
   Include breadcrumbs and back navigation.
3. Note Details screen: title, description, thumbnail, university/semester/subject/module, page count, size, price, Buy / Free-access button (wire to a placeholder until Phase 4), free preview viewer (preview.pdf in a responsive PDF viewer widget), "already purchased" state placeholder, related notes.
4. Notes list screens with filters (university, semester, subject, module, price range, free/paid) and sort (newest, popular, price). Use paginated queries and a reusable NoteCard.
5. Basic search bar: query `searchKeywords` (array-contains of the first token + client-side filter) and show results. Explain limitations and where Algolia/Typesense would plug in later.
6. Reusable widgets: LoadingView, ErrorView, EmptyView, ResponsiveGrid, Breadcrumbs, PriceTag.
7. Track "recently viewed" for logged-in users (users/{uid}/recentlyViewed, capped at 20).
8. Widget tests for NoteCard and filters; fix analyzer warnings.

Finish with a manual test checklist for web and mobile layouts.
```

---

### PHASE 4 — Payments, Purchases & Secure PDF Access

```
Read CLAUDE.md and docs/PrepNotes_Implementation_Plan.md (especially payment and security sections).

Goal: implement Phase 4 — Payments with Razorpay, My Purchases, and protected PDF access. This is the most security-critical phase. Plan first (include a sequence diagram in text), wait for approval.

Requirements:
Cloud Functions (TypeScript):
1. `createOrder` (callable, auth required): input noteIds[]; read prices from Firestore (NEVER trust client prices); reject unpublished notes and notes the user already owns; create Razorpay order via API; create `orders/{orderId}` with status 'created'; return razorpayOrderId, amount, key id.
2. `verifyPayment` (callable) AND `razorpayWebhook` (HTTPS, verifies webhook signature): verify signature server-side; mark order 'paid'; in a transaction create `users/{uid}/entitlements/{noteId}` for each note, increment note.purchaseCount, update stats/global (totalPurchases, totalRevenue). Must be idempotent (webhook + verify may both fire).
3. Failed/cancelled payments: update order status 'failed' with reason; handle `payment.failed` webhook.
4. `getNoteFileUrl` (callable, auth required): verify entitlement (or admin, or isFree note), then return a short-lived (≈5–10 min) signed URL for notes_private/{noteId}/file.pdf. Log access. Add basic rate limiting.
5. Store Razorpay key id/secret and webhook secret with Firebase Functions secrets, not in code.

Flutter:
6. Checkout flow: "Buy now" on Note Details → confirm dialog → call createOrder → open Razorpay (use razorpay_flutter on Android/iOS; for web, use Razorpay Checkout JS via JS interop — implement behind a `PaymentService` interface with platform-specific implementations) → call verifyPayment → show success screen or failure screen with retry. Handle: user closes checkout, network errors, double taps.
7. Optional cart (multiple notes in one order) — implement only if simple; otherwise single-note checkout and note it for later.
8. My Purchases screen: list purchased notes (from entitlements), purchase history with order id, date, amount, payment status; search within purchased notes; open note viewer; "Download/View".
9. Secure PDF Viewer: fetch signed URL via getNoteFileUrl, load in responsive PDF viewer, zoom/page navigation/search, handle expiry by re-requesting the URL. Optional: show buyer email as a subtle watermark overlay. Allow download only for entitled users (using the signed URL).
10. Update note details UI: states = not purchased / purchased (View) / free.
11. Update firestore.rules: entitlements and orders are read-only for owner, no client writes. Add emulator tests proving a client cannot create an entitlement or order, and cannot read other users' orders.
12. Test with Razorpay TEST mode; document the test cards/UPI and webhook setup (use Firebase Emulator + a tunnel for local webhook testing, explain steps).

Finish with a security checklist: list every way a user could try to get a PDF without paying and confirm each is blocked.
```

---

### PHASE 5 — Admin Dashboard, Users & Orders

```
Read CLAUDE.md and docs/PrepNotes_Implementation_Plan.md.

Goal: implement Phase 5 — Admin Dashboard, User Management, Order Management. Plan first.

Requirements:
1. Dashboard: cards for Total students, Total notes, Total purchases, Revenue (from stats/global — add Cloud Function triggers to keep counters correct on user create/delete, note create/delete, order paid/refunded; include a one-off callable to recompute stats). Lists: Most purchased notes (top 5), Recent purchases (10), Recent feedback (10), Recent requests (10). Add a simple revenue-over-time chart (last 30 days) using fl_chart, built from a daily aggregate doc stats_daily/{yyyy-MM-dd} maintained by Functions.
2. User Management: paginated student table, search by name/email, user detail page (profile info, purchases, orders, study time), disable/enable account (callable Function using Admin SDK), make/remove admin (calls setAdminClaim), no direct password access.
3. Order Management: paginated orders table with filters (status, date range), order detail (student, notes purchased, payment id, status), mark refunded (records refund; optionally call Razorpay refund API — explain and implement behind a confirmation dialog), export CSV.
4. All admin Functions verify the admin claim server-side. Add rule/function tests.
5. Make admin tables responsive (data tables on desktop, cards on small screens).

Finish with analyze + tests + manual test checklist.
```

---

### PHASE 6 — Resource Room

```
Read CLAUDE.md and docs/PrepNotes_Implementation_Plan.md.

Goal: implement Phase 6 — Resource Room (free resources) + admin management. Plan first.

Requirements:
1. Student side (public, no login needed): /resources with category chips (Previous Year Papers, Question Banks, Study Materials, Useful Websites, Coding Resources, AI Tools, Career Resources, Internship Resources, Hackathon Resources, Resume/CV Resources, University/Student Portals, Other), search, filters (category, type: link/file, tags), resource cards with description and "Open link" / "Download" buttons (url_launcher / Storage download URL). Paginated.
2. Admin side: Resource Room Management — CRUD for resources (title, description, category, tags, external link OR file upload to resources/{resourceId}/...), CRUD for categories (name, icon, order), activate/deactivate, delete with confirmation.
3. Seed default categories via a seeding script.
4. Rules: public read of active resources/categories, admin-only writes; Storage rules for resources/. Rule tests.
5. Add resources to the data used by the global search later (keep `searchKeywords`).
6. Track outbound clicks with Analytics events (resource_open).

Finish with analyze + tests + checklist.
```

---

### PHASE 7 — Student Voice (Feedback Zone)

```
Read CLAUDE.md and docs/PrepNotes_Implementation_Plan.md.

Goal: implement Phase 7 — Student Voice with exactly 3 sections + admin tabs. Plan first.

Student side (/student-voice), login required to submit:
A. Feature Requests & Website Problems — choose type (Feature request / Bug report / Suggestion), title, description, optional screenshot upload (stored under feedback_attachments/{uid}/...), optional device/browser info auto-attached for bugs.
B. Notes & University Requests — choose type (Subject notes / Module / Previous-year papers / Notes for a specific university / Add a new university); fields adapt per type (university dropdown or free text, subject, module, notes/comment).
C. General Feedback & Suggestions — rating (1–5 stars, optional), message, "what you like / dislike" optional fields.
All stored in `feedback` with `type`, `subType`, `status = 'new'`. Show a "My submissions" list with status so students can track what happened. Validate input lengths; add basic rate limiting (e.g., max N submissions/day via a Function or rules check).

Admin side (/admin/student-voice) with three tabs matching A, B, C:
- A: list, filter by status, view details, mark Reviewed / Resolved, add admin note, delete.
- B: list requested notes and requested universities separately, track status (new → in progress → added / rejected), quick action "Create university/note from this request" prefilled.
- C: list feedback with ratings, mark reviewed, delete. Show average rating.
Cloud Function `onFeedbackCreate` to update dashboard counters (and optionally send an email/FCM notification to admins).
Also notify the student (FCM or in-app badge) when status changes — implement in-app badge at minimum.

Rules: users can create own docs (validated fields, status must be 'new'), read own; cannot update status; admin full access. Emulator tests.

Finish with analyze + tests + checklist.
```

---

### PHASE 8 — Study Zone

```
Read CLAUDE.md and docs/PrepNotes_Implementation_Plan.md.

Goal: implement Phase 8 — Study Zone (Pomodoro + Stopwatch). Plan first.

Requirements:
1. Pomodoro Timer: default 25 min study / 5 min break, configurable study/break durations (and optional long break after 4 cycles), start/pause/reset/skip, circular progress UI, session counter, sound/vibration/notification at the end (web: use Notification API where available), keep accuracy when the app is backgrounded or the tab is throttled (compute from timestamps, not by counting ticks).
2. Stopwatch: start, pause, reset, lap (list of laps with split + total times).
3. Persist settings locally (shared_preferences). Persist active timer state so a refresh/restart doesn't lose it.
4. Study session tracking: when a study period completes (or the user stops), save a session to users/{uid}/studySessions (if logged in) and update users/{uid}.totalStudyMinutes through a Cloud Function or a safe transaction. Guests can use the timers without saving.
5. Study stats (basic): today's study time, this week's (bar chart with fl_chart), total sessions, current streak. Optional daily study goal with progress ring.
6. Show total study time on the Profile screen.
7. Rules for studySessions (owner only). Tests for the timer logic (pure Dart, unit-tested with a fake clock).

Finish with analyze + tests + checklist.
```

---

### PHASE 9 — Global Search, Polish, SEO & Analytics

```
Read CLAUDE.md and docs/PrepNotes_Implementation_Plan.md.

Goal: implement Phase 9 — global search and general website/app quality. Plan first.

Requirements:
1. Global Search page + search field in the app bar: query returns grouped results — Notes, Subjects, Universities, Resources. Filters: University, Semester, Subject, Module, Price. Debounced input, recent searches (local), empty state with suggestions. Implement with Firestore keyword queries first behind a `SearchService` interface; then, if I confirm, add an Algolia or Typesense implementation via a Firebase Extension (write the interface so swapping is easy).
2. Responsive audit of every screen at 360px, 768px, 1280px, 1920px. Fix overflow/layout issues.
3. Standard UI states: 404 page, global error page, loading skeletons (shimmer), empty states with illustrations/icons, snackbars/toasts for notifications, confirmation dialogs for destructive actions (centralize in core/widgets).
4. SEO basics for web: unique page titles per route (use a title-updating helper), meta description + OpenGraph/Twitter tags in web/index.html, favicon/manifest/PWA icons, robots.txt, sitemap.xml generator script (universities/subjects/notes from Firestore), canonical URLs with path URL strategy (`usePathUrlStrategy`). Note honestly the limits of SEO with Flutter Web and suggest a static landing page if needed.
5. Analytics: log events — sign_up, login, search, view_note, begin_checkout, purchase, resource_open, feedback_submit, study_session_complete. Add a central AnalyticsService.
6. Performance: image caching/placeholders, lazy loading, deferred loading of the admin module on web (`deferred as`), tree-shaken icons, check bundle size and report it. Use the `--wasm`/CanvasKit option appropriately and explain your choice.
7. Accessibility basics: semantics labels, contrast, keyboard navigation on web, text scaling.
8. Legal pages: Privacy Policy, Terms, Refund Policy (template content I will edit), Contact page — required for payment gateway approval.

Finish with analyze + a Lighthouse-style summary of what you could verify and what I need to check manually.
```

---

### PHASE 10 — Testing, Hardening & Release

```
Read CLAUDE.md and docs/PrepNotes_Implementation_Plan.md.

Goal: Phase 10 — production readiness. Plan first.

Requirements:
1. Security review: audit firestore.rules, storage.rules, and every Cloud Function for privilege escalation, missing auth checks, trusting client input, injection, and unbounded reads. Produce a findings list, then fix. Make sure the emulator rule-test suite covers every collection (allowed + denied cases) and runs with one command.
2. Enable and wire Firebase App Check (reCAPTCHA v3/Enterprise for web, Play Integrity for Android, App Attest/DeviceCheck for iOS) with a debug-token workflow for development. Enforce on Firestore, Storage, Functions.
3. Tests: unit tests for repositories/controllers, widget tests for key screens, one integration test of the happy path (login → browse → open note details) and, if feasible, a payment-flow test using mocks. Report coverage.
4. Environments: dev and prod Firebase projects with flavors (Android flavors, iOS schemes, web `--dart-define`/firebase target). Document how to switch.
5. CI/CD with GitHub Actions: on PR run `flutter analyze`, tests, functions build + lint; on merge to main deploy web to Firebase Hosting and functions/rules to prod (with manual approval for prod).
6. Backups and cost safety: enable Firestore scheduled backups/PITR, set budget alerts, review indexes and query costs.
7. Release checklist for: (a) Firebase Hosting + custom domain + SSL, (b) Google Play (app signing, icons, splash, privacy policy URL, data safety form), (c) Apple App Store (bundle id, certificates, privacy details). Generate app icons and native splash with flutter_launcher_icons / flutter_native_splash.
8. Switch Razorpay from TEST to LIVE: list every setting to change and how to verify with a small real payment, and a refund.
9. Produce a final README with architecture, setup, deployment, and troubleshooting.

Finish with a go-live checklist I can tick through.
```

---

## 8. Useful Reusable Prompts (for any time)

**Bug fixing**
```
I'm getting this error: [paste full error + stack trace]. It happens when [steps].
Find the root cause (don't just patch the symptom), explain it in 2–3 lines, fix it, and run flutter analyze.
```

**Code review of a phase**
```
Review everything changed in this branch against CLAUDE.md. Check: architecture rules, security rules, missing loading/error/empty states, responsiveness, pagination, hard-coded strings/colors, missing tests. Output a prioritized list, then fix the high-priority items.
```

**Adding a new feature safely**
```
I want to add [feature]. Don't code yet. Tell me which files/collections/rules/functions are affected, what could break, and propose a step-by-step plan. Wait for my approval.
```

**Refactor**
```
Refactor [file/feature] to follow the repository + Riverpod pattern in CLAUDE.md without changing behavior. Add tests first if none exist.
```

**Write rule tests**
```
Write Firebase Emulator tests for firestore.rules/storage.rules covering the collection(s) [names]: list every allowed and denied scenario (anonymous, student, other student, admin) and run them.
```

---

## 9. Future / Optional Ideas (after launch)

- Coupons/discounts, bundles (semester pack), wishlist
- Notes ratings & reviews, preview watermarking per buyer
- Push notifications (new notes for your university/semester)
- Daily study goals, leaderboard, streak badges
- Referral program
- Algolia/Typesense search, multilingual UI
- Admin roles (content editor vs. super admin)
- Offline reading for purchased notes (encrypted local cache)

---

## 10. Quick Start Checklist

- [ ] Install Flutter, Node, Firebase CLI, FlutterFire CLI, Git
- [ ] Create Firebase project (Blaze plan) + enable Auth/Firestore/Storage/Hosting
- [ ] Create repo, add `CLAUDE.md` and `/docs` files
- [ ] Run **Phase 0 prompt** in Claude Code
- [ ] Work phase by phase: plan → approve → build → analyze/test → commit → merge
- [ ] Use Razorpay TEST mode until Phase 10