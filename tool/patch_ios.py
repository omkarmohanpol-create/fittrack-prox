#!/usr/bin/env python3
"""Apply FitTrack Pro's iOS config to the folders made by `flutter create`.

ios/ is not checked in, so CI (and anyone building on a Mac) runs this after
`flutter create .`. It is safe to run more than once.

ios/Runner/Info.plist:
  * NSMotionUsageDescription (step counting), NSCameraUsageDescription and
    NSPhotoLibraryUsageDescription (profile picture)
  * the fittrackpro URL scheme Supabase uses after Google sign-in
ios/Podfile (created from Flutter's template if missing):
  * permission_handler only compiles in the permissions it is told about;
    this turns on PERMISSION_SENSORS (motion) and leaves the rest off
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLIST = ROOT / "ios/Runner/Info.plist"
PODFILE = ROOT / "ios/Podfile"

AUTH_SCHEME = "fittrackpro"

PLIST_KEYS = {
    "NSMotionUsageDescription":
        "FitTrack Pro counts your daily steps with the phone's motion sensor.",
    "NSCameraUsageDescription":
        "FitTrack Pro uses the camera to take your profile picture.",
    "NSPhotoLibraryUsageDescription":
        "FitTrack Pro lets you choose a profile picture from your photos.",
}

URL_TYPES = f"""\t<key>CFBundleURLTypes</key>
\t<array>
\t\t<dict>
\t\t\t<key>CFBundleTypeRole</key>
\t\t\t<string>Editor</string>
\t\t\t<key>CFBundleURLSchemes</key>
\t\t\t<array>
\t\t\t\t<string>{AUTH_SCHEME}</string>
\t\t\t</array>
\t\t</dict>
\t</array>
"""

# Flutter 3.24's ios Podfile template (packages/flutter_tools/templates/
# cocoapods/Podfile-ios-swift), used when ios/Podfile does not exist yet.
PODFILE_TEMPLATE = """# Uncomment this line to define a global platform for your project
platform :ios, '12.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
"""

PERMISSION_MACROS = """    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'PERMISSION_SENSORS=1'
    end
"""


def fail(msg):
    print(f"patch_ios: {msg}", file=sys.stderr)
    sys.exit(1)


def patch_plist():
    if not PLIST.exists():
        fail(f"{PLIST} not found. Run `flutter create .` first.")
    text = PLIST.read_text()
    end = text.rfind("</dict>")
    if end == -1:
        fail("no closing </dict> in Info.plist")
    additions = ""
    for key, value in PLIST_KEYS.items():
        if f"<key>{key}</key>" not in text:
            additions += f"\t<key>{key}</key>\n\t<string>{value}</string>\n"
    if "<key>CFBundleURLTypes</key>" not in text:
        additions += URL_TYPES
    elif f"<string>{AUTH_SCHEME}</string>" not in text:
        fail("Info.plist already has CFBundleURLTypes; add the "
             f"'{AUTH_SCHEME}' scheme to it by hand")
    if additions:
        text = text[:end] + additions + text[end:]
        PLIST.write_text(text)
    print("patch_ios: Info.plist ok")


def patch_podfile():
    text = PODFILE.read_text() if PODFILE.exists() else PODFILE_TEMPLATE
    if "PERMISSION_SENSORS" not in text:
        anchor = "    flutter_additional_ios_build_settings(target)\n"
        if anchor not in text:
            fail("Podfile has no flutter_additional_ios_build_settings(target)")
        text = text.replace(anchor, anchor + PERMISSION_MACROS, 1)
    PODFILE.write_text(text)
    print("patch_ios: Podfile ok")


if __name__ == "__main__":
    patch_plist()
    patch_podfile()
