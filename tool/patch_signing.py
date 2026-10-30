#!/usr/bin/env python3
"""Sign release builds with the fixed key in android_overrides/signing (both kts and groovy templates)."""
from pathlib import Path

root = Path(__file__).resolve().parent.parent
ks = (root / "android_overrides/signing/sudoquran.keystore").resolve()
kts = root / "android/app/build.gradle.kts"
groovy = root / "android/app/build.gradle"

if kts.exists():
    s = kts.read_text()
    if "sudoquranRelease" not in s:
        block = f'''    signingConfigs {{
        create("sudoquranRelease") {{
            storeFile = file("{ks}")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }}
    }}

    buildTypes {{'''
        s = s.replace("    buildTypes {", block, 1)
        s = s.replace('signingConfig = signingConfigs.getByName("debug")',
                      'signingConfig = signingConfigs.getByName("sudoquranRelease")')
        kts.write_text(s)
    print(kts.read_text()[kts.read_text().find("signingConfigs"):][:600])
elif groovy.exists():
    s = groovy.read_text()
    if "sudoquranRelease" not in s:
        block = f'''    signingConfigs {{
        sudoquranRelease {{
            storeFile file("{ks}")
            storePassword "android"
            keyAlias "androiddebugkey"
            keyPassword "android"
        }}
    }}

    buildTypes {{'''
        s = s.replace("    buildTypes {", block, 1)
        s = s.replace("signingConfig signingConfigs.debug", "signingConfig signingConfigs.sudoquranRelease")
        groovy.write_text(s)
    print("patched groovy")
else:
    raise SystemExit("no app build.gradle found")
