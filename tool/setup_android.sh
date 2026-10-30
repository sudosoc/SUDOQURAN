#!/usr/bin/env bash
# Generates the Android platform folder (if missing) and applies our overrides.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -d android ]; then
  flutter create --platforms=android --org com.sudosoc --project-name sudoquran .
fi
cp -r android_overrides/. android/
# One fixed signing key for every build, so new APKs install over old ones.
mkdir -p "$HOME/.android"
cp android_overrides/signing/sudoquran.keystore "$HOME/.android/debug.keystore"
# remove the template's Java MainActivity if one was generated
find android/app/src/main -name 'MainActivity.java' -delete || true
flutter pub get
dart run flutter_launcher_icons
echo "Android ready. Build with: flutter build apk --release --target-platform android-arm64"
