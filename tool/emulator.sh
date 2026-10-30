#!/usr/bin/env bash
# Boots an x86_64 emulator by hand (everything logged into smoke/), then runs smoke.sh.
mkdir -p smoke
exec > >(tee -a smoke/emulator_setup.txt) 2>&1
set -x
SDK="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
BIN="$SDK/cmdline-tools/latest/bin"
ls "$SDK" "$SDK/cmdline-tools" || true
IMG="system-images;android-33;google_apis;x86_64"
df -h / ; yes | "$BIN/sdkmanager" --install "emulator" "platform-tools" "$IMG" > smoke/sdkmanager.txt 2>&1
echo "sdkmanager exit $?"
echo no | "$BIN/avdmanager" create avd -n smoke -k "$IMG" -d pixel_6 --force
"$SDK/emulator/emulator" -avd smoke -no-window -gpu swiftshader_indirect -noaudio -no-boot-anim -no-snapshot \
  -memory 4096 > smoke/emulator_log.txt 2>&1 &
ADB="$SDK/platform-tools/adb"
timeout 300 "$ADB" wait-for-device || echo "DEVICE NEVER CAME UP"
for i in $(seq 1 120); do
  b=$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
  [ "$b" = "1" ] && break
  sleep 5
done
echo "boot_completed=$b after $i"
"$ADB" shell settings put global window_animation_scale 0
export PATH="$SDK/platform-tools:$PATH"
bash tool/smoke.sh
