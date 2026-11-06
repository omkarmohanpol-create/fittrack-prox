#!/usr/bin/env python3
"""Apply FitTrack Pro's Android config to the folders made by `flutter create`.

android/ is not checked in, so CI (and anyone setting up locally) runs this
after `flutter create .`. It is safe to run more than once.

android/app/build.gradle:
  * core library desugaring + desugar_jdk_libs (flutter_local_notifications 19)
  * compileSdk 35
  * release signing from android/key.properties when that file exists
    (CI writes it from repo secrets; see docs/DEPLOYMENT.md), otherwise the
    debug key, as Flutter's template does
AndroidManifest.xml:
  * POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED (reminders),
    ACTIVITY_RECOGNITION (step counting)
  * the two scheduled-notification receivers
  * the fittrackpro://login-callback link Supabase uses after Google sign-in
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GRADLE = ROOT / "android/app/build.gradle"
GRADLE_KTS = ROOT / "android/app/build.gradle.kts"
MANIFEST = ROOT / "android/app/src/main/AndroidManifest.xml"

AUTH_SCHEME = "fittrackpro"
AUTH_HOST = "login-callback"

PERMISSIONS = [
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.ACTIVITY_RECOGNITION",
]

RECEIVERS = '''        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
'''

AUTH_FILTER = f'''            <!-- Supabase sends the user back here after Google sign-in. -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="{AUTH_SCHEME}" android:host="{AUTH_HOST}" />
            </intent-filter>
'''

KEYSTORE_LOAD = '''def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

'''

SIGNING_CONFIGS = '''    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"]
                keyPassword = keystoreProperties["keyPassword"]
                storeFile = file(keystoreProperties["storeFile"])
                storePassword = keystoreProperties["storePassword"]
            }
        }
    }

'''


def fail(msg):
    print(f"patch_android: {msg}", file=sys.stderr)
    sys.exit(1)


def sub_once(pattern, repl, text, what):
    new, n = re.subn(pattern, repl, text, count=1)
    if n == 0:
        fail(f"could not find {what}")
    return new


def patch_gradle():
    if GRADLE_KTS.exists() and not GRADLE.exists():
        fail("found build.gradle.kts; this script expects the Groovy build.gradle "
             "made by Flutter 3.24. Use the Flutter version pinned in CI.")
    if not GRADLE.exists():
        fail(f"{GRADLE} not found. Run `flutter create .` first.")
    text = GRADLE.read_text()

    if "coreLibraryDesugaringEnabled" not in text:
        text = sub_once(r"compileOptions\s*\{",
                        "compileOptions {\n        coreLibraryDesugaringEnabled true",
                        text, "compileOptions block")

    text = re.sub(r"compileSdk\s*=?\s*flutter\.compileSdkVersion",
                  "compileSdk = 35", text)

    if "keystorePropertiesFile" not in text:
        text = sub_once(r"\nandroid\s*\{", "\n" + KEYSTORE_LOAD + "android {",
                        text, "android block")
        text = sub_once(r"(\n    buildTypes\s*\{)", "\n" + SIGNING_CONFIGS.rstrip("\n") + r"\n\1",
                        text, "buildTypes block")
        text = sub_once(r"signingConfig\s*=\s*signingConfigs\.debug",
                        "signingConfig = keystorePropertiesFile.exists()\n"
                        "                ? signingConfigs.release\n"
                        "                : signingConfigs.debug",
                        text, "release signingConfig")

    if "desugar_jdk_libs" not in text:
        text = text.rstrip() + (
            "\n\ndependencies {\n"
            "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n"
            "}\n")

    GRADLE.write_text(text)
    print("patch_android: build.gradle ok")


def patch_manifest():
    if not MANIFEST.exists():
        fail(f"{MANIFEST} not found. Run `flutter create .` first.")
    text = MANIFEST.read_text()

    missing = [p for p in PERMISSIONS if p not in text]
    if missing:
        lines = "".join(f'    <uses-permission android:name="{p}"/>\n' for p in missing)
        text = sub_once(r"(<manifest[^>]*>\n)", lambda m: m.group(1) + lines,
                        text, "<manifest> tag")

    if "ScheduledNotificationReceiver" not in text:
        text = sub_once(r"(<application[^>]*>\n)", lambda m: m.group(1) + RECEIVERS,
                        text, "<application> tag")

    if f'android:scheme="{AUTH_SCHEME}"' not in text:
        # Before the </activity> that closes MainActivity.
        m = re.search(r'android:name="\.MainActivity"', text)
        if not m:
            fail("no MainActivity in AndroidManifest.xml")
        end = text.find("</activity>", m.end())
        if end == -1:
            fail("MainActivity has no closing tag")
        line_start = text.rfind("\n", 0, end) + 1
        text = text[:line_start] + AUTH_FILTER + text[line_start:]

    MANIFEST.write_text(text)
    print("patch_android: AndroidManifest.xml ok")


if __name__ == "__main__":
    patch_gradle()
    patch_manifest()
