# Project Memory
## FitTrack Pro - Personal Fitness Tracker

Read this first in every session. Then docs/FEATURE-TICKETS.md (status), docs/DEPLOYMENT.md (setup),
docs/TESTING.md (tests).

---

## What the Product Does

Cross-platform (Android + iOS) fitness tracker: workouts (with editing, backdating, exercise library,
timer), progress charts, body measurements, steps, water, goals and reminders, with Supabase cloud sync,
offline support and a guest mode that keeps everything on the phone.

---

## Important Decisions

1. **Flutter + Supabase**; Provider for state; fl_chart for charts; local notifications only.
2. **Guest mode** when Supabase keys are missing or the user picks it. Guest data is not migrated into an
   account on sign-up.
3. **Secrets via --dart-define** (`SUPABASE_URL`, `SUPABASE_ANON_KEY`); GitHub secrets of the same names
   in CI. Never the service-role key in the app.
4. **Flutter pinned to 3.24.5 in CI**: keeps Groovy `build.gradle` (patch script needs it), avoids
   `withOpacity` deprecations.
5. **android/ and ios/ are generated**, then `tool/patch_android.py` / `tool/patch_ios.py` (permissions,
   notification receivers, Google sign-in link `fittrackpro://login-callback`, release signing from
   `android/key.properties`, iOS permission texts and Podfile `PERMISSION_SENSORS=1`).
6. **Ids are made on the device** (`newUuid()`); workouts are saved through the `save_workout` SQL
   function (upsert + replace exercises in one transaction). So retries after a lost connection never
   duplicate, and offline edits can be queued.
7. **Offline**: signed-in workouts and water that fail to reach Supabase *for network reasons* go to a
   per-user pending queue (`LocalStore`), flushed on load and app resume; a server rejection
   (`PostgrestException` etc., see `services/sync_errors.dart`) is shown as an error instead. Last-loaded
   data is cached per user. Sign-out and account deletion clear that user's cache and queue (sign-out
   warns if anything is unsynced).
8. **Account deletion** runs in the `delete-account` Edge Function (service-role key stays server-side);
   deleting the auth user cascades to all tables; the function also deletes avatar files.
9. **Steps** come from the `pedometer` step sensor (cumulative since boot); `StepCounterState` turns it
   into per-day counts across restarts and day changes. Opt-in, needs ACTIVITY_RECOGNITION / motion
   permission. Synced to `daily_steps`.

---

## Where the source is

Session 3 delivered the complete repo as `fittrack-pro-full.zip` in chat (the shared Drive folder never
had session 1's code; Omkar asked not to upload session 3's later work to Drive). Use that zip, or the
GitHub repo once pushed, as the base.

---

## Live Supabase project (created in session 3)

- Project `fittrack-pro`, ref `mxdsnxilfryyincyjuvi`, region Mumbai (ap-south-1), free plan,
  URL https://mxdsnxilfryyincyjuvi.supabase.co
- Applied: migrations `fittrack_initial_schema` (= schema.sql) and `lock_down_handle_new_user`
  (revoke EXECUTE on the trigger function; also in schema.sql now). Security advisor: no findings.
- Edge Function `delete-account` deployed (verify_jwt on).
- Smoke-tested live (rolled back): signup trigger, save_workout insert + edit under RLS.
- The app uses the legacy **anon** key (JWT) as SUPABASE_ANON_KEY; it is public by design.
- Still manual in the dashboard: Redirect URL `fittrackpro://login-callback`, Google provider.

## How code was verified in session 3 (no Flutter SDK available)

- `dart analyze` (Dart 3.13 from conda-forge) against the real Flutter 3.24.5 framework source,
  engine `dart:ui` sources (engine commit a18df97c) and every package fetched from GitHub at matching
  versions (pub.dev was blocked). Result: **0 errors, 0 warnings**.
- Pure-Dart logic executed for real (25 checks: UUIDs, formatters, zoom, step counter, save params).
- `supabase/schema.sql` run twice on PostgreSQL 16 + `supabase/tests/schema_test.sql` (RLS, save_workout,
  cascade delete): all pass.
- `deno check` on the Edge Function against real supabase-js types: passes.
- Patch scripts run twice against Flutter 3.24.5's own `flutter create` templates: valid XML/plist.
- NOT run: `flutter test` (needs the engine), any device run, any GitHub Actions run.

---

## Session history

- **Session 1**: app written (auth, dashboard, workouts, charts, water, goals, reminders, export).
- **Session 2**: static review; fixed hero tags, swipe-delete sync, water save errors, guest persistence,
  per-user goal cache, workout order, empty charts; schema re-runnable.
- **Session 3**: CI pipeline; Android/iOS patch scripts; backdating; expired-session redirect (found the
  app silently switched signed-in users to the guest store); then every remaining feature: edit
  workout, exercise library, timer, body measurements, steps, avatar, account deletion, Google sign-in,
  offline cache + queue, pinch zoom, Inter font, release signing, docs, tests.

---

## Pending

- [ ] Push to GitHub, let CI run `flutter analyze` / `flutter test` / builds; fix anything it reports
      (most likely spots: widget-test timing, `pedometer`/`permission_handler` versions pub resolves)
- [ ] Omkar: Supabase project + `schema.sql` + secrets; deploy `delete-account`; Google OAuth (DEPLOYMENT.md)
- [ ] Device testing (docs/TESTING.md manual list)
- [ ] App icon, splash, privacy policy, store listings, Sign in with Apple for iOS
- [ ] Nice to have: move guest data into a new account; Health Connect / HealthKit steps; offline
      queue for deletes, measurements and custom exercises
