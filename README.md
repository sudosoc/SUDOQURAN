# SUDOQURAN — القرآن الكريم للعربية

تطبيق Flutter للقرآن والرقية الشرعية، معمول مخصوص لشاشة العربية:
Android 13 · 2000×1200 landscape · UIS7870SC · 6GB RAM.

## المميزات
- **16 قارئ** + قسم **الرقية الشرعية** (ماهر المعيقلي، حسن صالح).
- **أوفلاين بالكامل** بعد التحميل: كل قارئ له زرار "تحميل الكل" (من mp3quran.net)، أو **استيراد من فلاشة/كارت**.
- الاستيراد بيتعرف على السورة لوحده من اسم الملف: `001.mp3` / `018 الكهف.mp3` / `سورة الكهف.mp3`.
- الرقية بصوت المعيقلي بتتبني من الآيات نفسها (everyayah.com) — ~110 آية، حوالي 25MB.
- تشغيل في الخلفية + **أزرار الدريكسيون** (media session) + إشعار.
- **استكمال تلقائي** من مكان ما وقفت لما العربية تدور.
- UI **Glassmorphism** بأزرار كبيرة (≥ 56dp) مناسبة للسواقة، والمشغل على الشمال جنب السواق.

## البيلد
### من GitHub (من غير ما تنزّل حاجة)
1. اعمل repo جديد (مثلاً `sudosoc/SUDOQURAN`) وارفع الفولدر ده.
2. الـ workflow `.github/workflows/build-apk.yml` هيشتغل لوحده.
3. من **Actions → آخر run → Artifacts** نزّل `SUDOQURAN-apk`.

### لوكال
```bash
bash tool/setup_android.sh      # flutter create + overrides + icons
flutter build apk --release --target-platform android-arm64
```
الـ APK: `build/app/outputs/flutter-apk/app-release.apk` — انقله للشاشة بـ ShareMe أو فلاشة.

## القراء اللي مش على mp3quran
التطبيق بيسأل API بتاع mp3quran أول ما يتفتح ويطابق الأسماء. اللي مش موجود (غالبًا: عمر علي، بلال الغازي، ماجد الدعوس، عبد الرحمن الحاج…) هيظهر عليه "استيراد من فلاشة".
تقدر كمان تحط **رابط سيرفر مخصص** لأي قارئ (⋮ → تعديل رابط السيرفر) بشرط الملفات تكون `001.mp3 … 114.mp3`.

## الملفات
```
lib/
  data/       surahs, reciters, ruqyah verses
  services/   settings, mp3quran resolver, library (downloads/imports), player
  ui/         glass widgets, home shell, quran, ruqyah, settings, now-playing
android_overrides/   AndroidManifest + MainActivity (background audio)
```
