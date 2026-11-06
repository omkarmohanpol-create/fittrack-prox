# Testing

## Automated

| What | Where | Run |
| --- | --- | --- |
| Dart unit + widget tests | `test/core_test.dart`, `test/features_test.dart`, `test/auth_session_test.dart` | `flutter test` |
| Static analysis | whole project | `flutter analyze` |
| Database schema | `supabase/tests/` | `PGHOST=localhost PGUSER=postgres supabase/tests/run.sh` |
| Edge Function types | `supabase/functions/delete-account` | `deno check supabase/functions/delete-account/index.ts` |

All four run in GitHub Actions on every push (`.github/workflows/build.yml`).

The Dart tests run in guest mode (no Supabase) with `SharedPreferences.setMockInitialValues`, and inject
a fake step sensor into `StepsProvider`. They cover formatters, validators, models and JSON round trips,
chart bucketing and zoom, the step counter (restarts, day changes), workout ordering, backdating,
editing, offline merge, water, the exercise library, measurements, local data clearing, session expiry
and its redirect.

`supabase/tests/schema_test.sql` runs `schema.sql` on plain PostgreSQL with small stand-ins for
Supabase's `auth` and `storage` schemas, signed in as two users. It checks the signup trigger,
`save_workout` (insert, retry without duplicates, edit), that one user cannot read or overwrite another's
data or avatar folder, that signed-out callers cannot save, the value checks, and that deleting an
account removes all of its rows.

## Manual checks on a phone

Use a debug APK from the Actions run (or `flutter run`) with Supabase connected.

1. **Accounts**: sign up with email, confirm, sign in; sign out and in again; Google sign-in.
2. **Workouts**: log a strength workout with library exercises; log one for last week; tap one to edit
   its name, date and exercises; swipe to delete.
3. **Offline**: turn on airplane mode, log a workout and a glass of water (cloud-off icon shows), turn
   airplane mode off and return to the app: the icon disappears and the data is in Supabase's
   Table Editor.
4. **Timer**: start, pause, rest 30 s (phone vibrates at the end), finish → minutes are filled in.
5. **Charts**: Progress → 30D → pinch to zoom, drag, double-tap to reset.
6. **Measurements**: add two weights on different days → chart and change appear.
7. **Steps**: turn on, allow the permission, walk → the count rises; restart the phone → the count is kept.
8. **Profile picture**: choose from gallery, take a photo, remove.
9. **Reminders**: set the workout reminder 2 minutes ahead, lock the phone; restart the phone and check
   the next one still arrives.
10. **Session expiry**: in Supabase → Authentication → Users, sign the user out of all sessions
    (or delete the user) → the app returns to login with "Your session expired".
11. **Delete account**: Settings → Delete account → type DELETE → the user and their rows are gone.
12. **Dark/light mode, metric/imperial**: check every screen in both.
