import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'library.dart';
import 'player.dart';
import 'settings.dart';

class City {
  final String id;
  final String name;
  final double lat;
  final double lng;
  const City(this.id, this.name, this.lat, this.lng);
}

const cities = <City>[
  City('tenth', 'العاشر من رمضان', 30.2964, 31.7433),
  City('cairo', 'القاهرة', 30.0444, 31.2357),
  City('giza', 'الجيزة', 30.0131, 31.2089),
  City('october', '6 أكتوبر', 29.9285, 30.9188),
  City('obour', 'العبور', 30.2280, 31.4790),
  City('shorouk', 'الشروق', 30.1427, 31.6286),
  City('alex', 'الإسكندرية', 31.2001, 29.9187),
  City('zagazig', 'الزقازيق', 30.5877, 31.5020),
  City('benha', 'بنها', 30.4659, 31.1848),
  City('mansoura', 'المنصورة', 31.0409, 31.3785),
  City('tanta', 'طنطا', 30.7865, 31.0004),
  City('damietta', 'دمياط', 31.4165, 31.8133),
  City('kafr', 'كفر الشيخ', 31.1107, 30.9388),
  City('ismailia', 'الإسماعيلية', 30.5965, 32.2715),
  City('portsaid', 'بورسعيد', 31.2653, 32.3019),
  City('suez', 'السويس', 29.9668, 32.5498),
  City('fayoum', 'الفيوم', 29.3084, 30.8428),
  City('benisuef', 'بني سويف', 29.0661, 31.0994),
  City('minya', 'المنيا', 28.0871, 30.7618),
  City('assiut', 'أسيوط', 27.1810, 31.1837),
  City('sohag', 'سوهاج', 26.5591, 31.6957),
  City('qena', 'قنا', 26.1551, 32.7160),
  City('luxor', 'الأقصر', 25.6872, 32.6396),
  City('aswan', 'أسوان', 24.0889, 32.8998),
  City('hurghada', 'الغردقة', 27.2579, 33.8116),
  City('sharm', 'شرم الشيخ', 27.9158, 34.3300),
  City('matrouh', 'مرسى مطروح', 31.3543, 27.2373),
  City('makkah', 'مكة المكرمة', 21.4225, 39.8262),
  City('madinah', 'المدينة المنورة', 24.4672, 39.6111),
];

City cityById(String id) => cities.firstWhere((c) => c.id == id, orElse: () => cities.first);

const prayerNames = ['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء'];

/// Prayer times with the Egyptian General Authority of Survey method
/// (Fajr 19.5°, Isha 17.5°, Asr Shafi'i). Works fully offline.
class PrayerTimes {
  static double _d2r(double d) => d * math.pi / 180;
  static double _r2d(double r) => r * 180 / math.pi;
  static double _fix(double a, double b) {
    final r = a - b * (a / b).floorToDouble();
    return r < 0 ? r + b : r;
  }

  static double _julian(int y, int m, int d) {
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = (y / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (y + 4716)).floorToDouble() + (30.6001 * (m + 1)).floorToDouble() + d + b - 1524.5;
  }

  /// [declination in degrees, equation of time in hours]
  static List<double> _sun(double jd) {
    final d = jd - 2451545.0;
    final g = _fix(357.529 + 0.98560028 * d, 360);
    final q = _fix(280.459 + 0.98564736 * d, 360);
    final l = _fix(q + 1.915 * math.sin(_d2r(g)) + 0.020 * math.sin(_d2r(2 * g)), 360);
    final e = 23.439 - 0.00000036 * d;
    final ra = _fix(_r2d(math.atan2(math.cos(_d2r(e)) * math.sin(_d2r(l)), math.cos(_d2r(l)))) / 15, 24);
    final eqt = q / 15 - ra;
    final decl = _r2d(math.asin(math.sin(_d2r(e)) * math.sin(_d2r(l))));
    return [decl, eqt];
  }

  /// Returns the six times (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha) for [day].
  static List<DateTime> forDay(DateTime day, double lat, double lng) {
    final tz = DateTime(day.year, day.month, day.day, 12).timeZoneOffset.inMinutes / 60.0;
    final jd = _julian(day.year, day.month, day.day) - lng / (15 * 24);

    double midDay(double t) => _fix(12 - _sun(jd + t)[1], 24);
    double angleTime(double angle, double t, bool ccw) {
      final decl = _sun(jd + t)[0];
      final noon = midDay(t);
      final v = (-math.sin(_d2r(angle)) - math.sin(_d2r(decl)) * math.sin(_d2r(lat))) /
          (math.cos(_d2r(decl)) * math.cos(_d2r(lat)));
      final tt = _r2d(math.acos(v.clamp(-1.0, 1.0))) / 15;
      return noon + (ccw ? -tt : tt);
    }

    double asr(double t) {
      final decl = _sun(jd + t)[0];
      final angle = -_r2d(math.atan(1 / (1 + math.tan(_d2r((lat - decl).abs())))));
      return angleTime(angle, t, false);
    }

    final raw = <double>[
      angleTime(19.5, 5 / 24, true),
      angleTime(0.833, 6 / 24, true),
      midDay(12 / 24),
      asr(13 / 24),
      angleTime(0.833, 18 / 24, false),
      angleTime(17.5, 18 / 24, false),
    ];
    final base = DateTime(day.year, day.month, day.day);
    return [
      for (var i = 0; i < raw.length; i++)
        base.add(Duration(seconds: ((raw[i] + tz - lng / 15) * 3600).round() + (i == 2 ? 60 : 0)))
    ];
  }
}

/// Watches the clock and fires the adhan alert.
class Prayer extends ChangeNotifier {
  Prayer._();
  static final Prayer instance = Prayer._();

  Timer? _timer;
  final Set<String> _fired = {};

  /// Banner text while an adhan alert is showing.
  final ValueNotifier<String?> banner = ValueNotifier(null);

  List<DateTime> today = [];

  static const _alarms = MethodChannel('sudoquran/alarms');
  String _schedSig = '';

  void start() {
    _recalc();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
    Settings.instance.addListener(() {
      _recalc();
      scheduleNative();
    });
    Library.instance.addListener(scheduleNative);
    scheduleNative();
  }

  /// Hands the next 7 days of adhan (and pre-alert) times to Android's
  /// AlarmManager, so they fire even when the app is closed.
  Future<void> scheduleNative() async {
    final st = Settings.instance;
    final c = cityById(st.prayerCity);
    final adhanPath = Library.instance.adhanFile()?.path ?? '';
    final on = st.prayerEnabled && st.bgAdhan;
    final sig = '$on|${c.id}|$adhanPath|${st.preAlert}|${st.adhanSound}|${DateTime.now().day}';
    if (sig == _schedSig) return;
    _schedSig = sig;
    try {
      if (!on) {
        await _alarms.invokeMethod('cancel');
        return;
      }
      final now = DateTime.now();
      final items = <Map<String, Object>>[];
      for (var d = 0; d < 7; d++) {
        final day = DateTime(now.year, now.month, now.day).add(Duration(days: d));
        final t = PrayerTimes.forDay(day, c.lat, c.lng);
        for (var i = 0; i < t.length; i++) {
          if (i == 1) continue;
          if (t[i].isAfter(now)) {
            items.add({
              'at': t[i].millisecondsSinceEpoch,
              'title': 'أذان ${prayerNames[i]}',
              'body': 'حان الآن موعد صلاة ${prayerNames[i]} — ${c.name}',
              'sound': st.adhanSound ? adhanPath : '',
            });
          }
          final pre = t[i].subtract(Duration(minutes: st.preAlert));
          if (st.preAlert > 0 && pre.isAfter(now)) {
            items.add({
              'at': pre.millisecondsSinceEpoch,
              'title': '${prayerNames[i]} بعد ${st.preAlert} دقايق',
              'body': 'استعد لصلاة ${prayerNames[i]}',
              'sound': '',
            });
          }
        }
      }
      await _alarms.invokeMethod('schedule', {'items': items});
    } catch (_) {
      _schedSig = '';
    }
  }

  /// True when Android will play the adhan itself (app closed or not).
  bool get nativeHandlesSound =>
      Settings.instance.prayerEnabled &&
      Settings.instance.bgAdhan &&
      Settings.instance.adhanSound &&
      Library.instance.adhanFile() != null;

  void _recalc() {
    final c = cityById(Settings.instance.prayerCity);
    today = PrayerTimes.forDay(DateTime.now(), c.lat, c.lng);
    notifyListeners();
  }

  /// Next prayer (skips sunrise): (name, time).
  (String, DateTime) get next {
    final now = DateTime.now();
    if (today.isEmpty || today.first.day != now.day) _recalc();
    for (var i = 0; i < today.length; i++) {
      if (i == 1) continue;
      if (today[i].isAfter(now)) return (prayerNames[i], today[i]);
    }
    final c = cityById(Settings.instance.prayerCity);
    final tomorrow = PrayerTimes.forDay(now.add(const Duration(days: 1)), c.lat, c.lng);
    return (prayerNames[0], tomorrow[0]);
  }

  void _tick() {
    final now = DateTime.now();
    if (today.isEmpty || today.first.day != now.day) _recalc();
    notifyListeners();
    if (!Settings.instance.prayerEnabled) return;
    final pre = Settings.instance.preAlert;
    for (var i = 0; i < today.length; i++) {
      if (i == 1 || pre <= 0) continue;
      final t = today[i].subtract(Duration(minutes: pre));
      final key = 'pre-${t.year}-${t.month}-${t.day}-$i';
      final diff = now.difference(t).inSeconds;
      if (diff >= 0 && diff < 90 && !_fired.contains(key)) {
        _fired.add(key);
        banner.value = '${prayerNames[i]} بعد $pre دقايق';
        Future.delayed(const Duration(seconds: 40), () {
          if (banner.value?.startsWith(prayerNames[i]) ?? false) banner.value = null;
        });
      }
    }
    for (var i = 0; i < today.length; i++) {
      if (i == 1) continue;
      final t = today[i];
      final key = '${t.year}-${t.month}-${t.day}-$i';
      final diff = now.difference(t).inSeconds;
      if (diff >= 0 && diff < 90 && !_fired.contains(key)) {
        _fired.add(key);
        _fire(prayerNames[i]);
      }
    }
  }

  void _fire(String name) {
    banner.value = 'حان الآن موعد أذان $name';
    Player.instance.adhanInterrupt(name, silent: nativeHandlesSound);
    Future.delayed(const Duration(minutes: 3), () {
      if (banner.value?.contains(name) ?? false) banner.value = null;
    });
  }

  /// Manual test from settings.
  void test() => _fire(next.$1);
}

const hijriMonths = [
  'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
  'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
];

/// Tabular (Kuwaiti) Hijri date; [offset] days lets the user align with the official sighting.
(int, int, int) hijri(DateTime g, [int offset = 0]) {
  final d = g.add(Duration(days: offset));
  var y = d.year, m = d.month;
  if (m < 3) {
    y -= 1;
    m += 12;
  }
  final a = (y / 100).floor();
  final b = 2 - a + (a / 4).floor();
  final jd = (365.25 * (y + 4716)).floor() + (30.6001 * (m + 1)).floor() + d.day + b - 1524;
  const iyear = 10631.0 / 30.0;
  const shift1 = 8.01 / 60.0;
  var z = (jd - 1948084).toDouble();
  final cyc = (z / 10631.0).floor();
  z = z - 10631 * cyc;
  final j = ((z - shift1) / iyear).floor();
  final iy = 30 * cyc + j;
  z = z - (j * iyear + shift1).floor();
  var im = ((z + 28.5001) / 29.5).floor();
  if (im == 13) im = 12;
  final id = (z - (29.5001 * im - 29).floor()).round();
  return (id, im, iy);
}

String hijriText(DateTime g, [int offset = 0]) {
  final (d, m, y) = hijri(g, offset);
  return '$d ${hijriMonths[(m - 1).clamp(0, 11)]} $y هـ';
}

String fmtClock(DateTime t, {bool h24 = false, bool seconds = false}) {
  final mm = t.minute.toString().padLeft(2, '0');
  final ss = t.second.toString().padLeft(2, '0');
  if (h24) return '${t.hour.toString().padLeft(2, '0')}:$mm${seconds ? ':$ss' : ''}';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:$mm${seconds ? ':$ss' : ''} ${t.hour < 12 ? 'ص' : 'م'}';
}

String fmtCountdown(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '$h س $m د';
  return '$m دقيقة';
}
