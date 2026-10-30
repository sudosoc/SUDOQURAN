# SUDOQURAN — القرآن الكريم للعربية

تطبيق Flutter للقرآن والرقية الشرعية، معمول مخصوص لشاشة العربية:
Android 13 · 2000×1200 landscape · UIS7870SC · 6GB RAM.

## المميزات
- **16 قارئ** + قسم **الرقية الشرعية** (ماهر المعيقلي، حسن صالح).
- **المصادر بتتجاب أوتوماتيك**: `tool/build_sources.py` بيشتغل على GitHub Actions، بيدوّر في mp3quran.net و quranicaudio.com و archive.org، ويتأكد إن كل لينك بيرجع صوت فعلًا، ويكتب `assets/sources.json`. التطبيق بياخد آخر نسخة منه كل ما يفتح، وبيتحدث كل أسبوع لوحده.
- كل سورة ليها **أكتر من مصدر**: لو مصدر وقع، التحميل بيجرب اللي بعده.
- **تحميل كل حاجة للأوفلاين** بزرار واحد من الإعدادات، وبيكمل لوحده لو العربية قفلت.
- الرقية بصوت المعيقلي متجمعة من الآيات (everyayah.com) + تسجيلات كاملة من archive.org.
- تشغيل في الخلفية + **أزرار الدريكسيون** + **استكمال تلقائي**.
- UI **Glassmorphism** بأزرار كبيرة مناسبة للسواقة.

## تقرير المصادر
`tool/report.md` بيقولك كل قارئ لقيناله كام سورة ومن أنهي مصدر.

## البيلد
### الأسهل
نزّل `SUDOQURAN.apk` من **[Releases → latest](https://github.com/sudosoc/SUDOQURAN/releases/latest)** — بيتبني أوتوماتيك مع كل تعديل.

### لوكال
```bash
bash tool/setup_android.sh      # flutter create + overrides + icons
flutter build apk --release --target-platform android-arm64
```
الـ APK: `build/app/outputs/flutter-apk/app-release.apk` — انقله للشاشة بـ ShareMe أو فلاشة.

## الملفات
```
lib/
  data/       surahs, reciters, ruqyah verses
  services/   settings, mp3quran resolver, library (downloads/imports), player
  ui/         glass widgets, home shell, quran, ruqyah, settings, now-playing
android_overrides/   AndroidManifest + MainActivity (background audio)
```
