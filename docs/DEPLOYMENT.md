# Deployment: connecting Supabase and shipping the app

Everything here is done once per Supabase project. Steps 1–4 are required for accounts and sync;
5–7 turn on optional features; 8–9 are for store releases.

## 1. Create the Supabase project

1. Sign in at <https://supabase.com> and create a project (the free tier is enough).
   Pick the region closest to your users (for India: Mumbai, `ap-south-1`).
2. Save the database password somewhere safe. The app does not need it.

## 2. Create the tables and security rules

1. In the dashboard open **SQL Editor → New query**.
2. Paste the whole of `supabase/schema.sql` and press **Run**.
3. You should see "Success. No rows returned". Notices like "already exists, skipping" are fine.

The script is safe to run again, so after any app update that changes `schema.sql`, just run it again.
It creates:

| What | Purpose |
| --- | --- |
| `users`, `workouts`, `workout_exercises`, `water_logs`, `goals`, `reminders` | core data |
| `custom_exercises`, `body_measurements`, `daily_steps` | exercise library, measurements, steps |
| row level security on every table | each user can only read and change their own rows |
| `save_workout()` | saves a workout and its exercises in one step, safe to retry |
| `on_auth_user_created` trigger | creates the profile row when someone signs up |
| `avatars` storage bucket | profile pictures, 5 MB max, JPEG/PNG, owner-only writes |

Check: **Table Editor** lists the tables, and **Storage** shows an `avatars` bucket.

## 3. Connect the app

1. Open **Project Settings → API** (in newer dashboards: **Project Settings → Data API** and **API Keys**).
2. Copy the **Project URL** (`https://xxxx.supabase.co`) and the **anon / public** key.
   Do **not** use the `service_role` / secret key anywhere in the app.
3. Give them to the app:
   - **GitHub Actions builds**: repo → **Settings → Secrets and variables → Actions → New repository
     secret**: `SUPABASE_URL` and `SUPABASE_ANON_KEY`. The next push builds an APK that uses them.
   - **Running locally**:

     ```bash
     flutter run \
       --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
       --dart-define=SUPABASE_ANON_KEY=eyJ...
     ```

Check: open the app. The login screen should no longer say "Cloud sync is not configured".

## 4. Email sign-up settings

**Authentication → Sign In / Providers → Email**:

- With **Confirm email** on (the default), new users must tap the link in their email before signing in.
  The app shows a "check your email" message after sign-up.
- For testing you can turn it off so sign-up signs in straight away.

The free plan's built-in email sender is rate-limited (a few emails per hour). For real users set up your
own SMTP under **Authentication → Emails → SMTP Settings**.

## 5. Google sign-in (optional)

1. **Supabase → Authentication → URL Configuration → Redirect URLs → Add URL**:
   `fittrackpro://login-callback`
   (This is the link the app opens after Google. It is set in `lib/utils/constants.dart` and the patch
   scripts add it to Android and iOS.)
2. **Google Cloud Console** (<https://console.cloud.google.com>):
   1. Create a project, then **APIs & Services → OAuth consent screen**: External, app name, support email.
   2. **Credentials → Create credentials → OAuth client ID → Web application**.
   3. Under **Authorized redirect URIs** add the callback URL that Supabase shows on its Google provider
      page (`https://xxxx.supabase.co/auth/v1/callback`).
   4. Copy the **Client ID** and **Client secret**.
3. **Supabase → Authentication → Sign In / Providers → Google**: enable it and paste the client ID and secret.

Check: the login screen's **Continue with Google** opens the browser, you pick an account, and the app
opens on the dashboard.

## 6. Account deletion (required for Play Store / App Store)

Deleting an account needs the service-role key, so it runs on Supabase's servers as an Edge Function
(`supabase/functions/delete-account/index.ts`). Deploy it once:

```bash
npm install -g supabase            # or: brew install supabase/tap/supabase
supabase login
supabase link --project-ref xxxx   # the "xxxx" in your project URL
supabase functions deploy delete-account
```

No secrets need to be set: Supabase gives every function `SUPABASE_URL`, `SUPABASE_ANON_KEY` and
`SUPABASE_SERVICE_ROLE_KEY` automatically. Keep **Verify JWT** on (the default).

Check: **Edge Functions** in the dashboard lists `delete-account`. In the app, **Settings → Delete
account** removes the user from **Authentication → Users**, together with all their rows and their
profile picture.

## 7. Steps (optional, nothing to set up)

Step counting is off until the user turns it on (dashboard card or **Settings → Count steps**); the app
then asks for the physical-activity (Android) or motion (iOS) permission. The patch scripts add the
permission declarations.

## 8. Android release signing

1. Create an upload key once and keep it safe (losing it means you cannot update the app):

   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias upload
   ```

2. Add these GitHub secrets:

   | Secret | Value |
   | --- | --- |
   | `ANDROID_KEYSTORE_BASE64` | output of `base64 -w0 upload-keystore.jks` (macOS: `base64 -i upload-keystore.jks`) |
   | `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
   | `ANDROID_KEY_ALIAS` | `upload` |
   | `ANDROID_KEY_PASSWORD` | the key password |

3. Push. The `android` job then also uploads **fittrack-pro-release-aab**, ready for Play Console.

Locally, create `android/key.properties` (it is git-ignored):

```
storeFile=/full/path/to/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

and run `flutter build appbundle --release --dart-define=...`.

## 9. Store checklist

- [ ] App icon and splash (`flutter_launcher_icons` or replace `android/app/src/main/res/mipmap-*` and
      the iOS asset catalog after `flutter create`)
- [ ] Choose your final application id before the first upload; it cannot change later. It comes from
      `flutter create --org com.fittrack` (giving `com.fittrack.fittrack_pro`); the patch scripts work
      with any id
- [ ] Privacy policy URL (both stores require one; mention Supabase as the data processor)
- [ ] Play Console **Data safety** form: email, name, fitness data, photos (optional), all encrypted in
      transit, deletable in the app
- [ ] Account deletion: in-app (done) and a web link or email for users who uninstalled
- [ ] iOS: an Apple Developer account and signing in Xcode. Apple's guideline 4.8 expects apps that
      offer Google sign-in to also offer an equivalent privacy-focused option such as Sign in with Apple
- [ ] Test on real devices: steps, notifications after reboot, Google sign-in, offline mode

## Troubleshooting

| Problem | Fix |
| --- | --- |
| Login screen says cloud sync is not configured | The `--dart-define` values (or GitHub secrets) are missing or misspelled |
| "Could not save the workout" right after setup | `schema.sql` was not run, or ran only partly: run it again |
| Google opens but never returns to the app | `fittrackpro://login-callback` is not in Redirect URLs, or `tool/patch_android.py` was not run |
| Delete account says it could not delete | The `delete-account` function is not deployed |
| Profile picture upload fails | The `avatars` bucket is missing: run `schema.sql` again |
