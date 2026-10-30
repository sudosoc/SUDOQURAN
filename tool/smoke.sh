#!/usr/bin/env bash
# Installs the x64 APK on the emulator, launches it, and collects crash logs.
set -x
mkdir -p smoke
adb install -r -g build/app/outputs/flutter-apk/app-release.apk 2>&1 | tee smoke/install.txt
adb logcat -c
adb shell monkey -p com.sudosoc.sudoquran -c android.intent.category.LAUNCHER 1
sleep 45
adb exec-out screencap -p > smoke/screen1.png
adb shell pidof com.sudosoc.sudoquran > smoke/pid.txt || echo "NOT RUNNING" > smoke/pid.txt
# relaunch once more (crash loops show up on second start too)
adb shell monkey -p com.sudosoc.sudoquran -c android.intent.category.LAUNCHER 1
sleep 20
adb exec-out screencap -p > smoke/screen2.png
adb logcat -d > smoke/logcat_full.txt
grep -nE "AndroidRuntime|FATAL|Exception|flutter|sudoquran|audioservice|DEBUG   :" smoke/logcat_full.txt | head -400 > smoke/logcat.txt || true
exit 0
