import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Live speed + trip computer from the head unit's GPS (native LocationManager).
class Gps extends ChangeNotifier {
  Gps._();
  static final Gps instance = Gps._();

  static const _ch = EventChannel('sudoquran/gps');
  StreamSubscription<dynamic>? _sub;
  int _listeners = 0;

  // live
  double speedKmh = 0; // smoothed
  double rawKmh = 0;
  double heading = -1;
  double altitude = 0;
  double accuracy = -1;
  int sats = 0;
  int satsUsed = 0;
  bool hasFix = false;
  String? error;
  DateTime? lastFix;

  // trip
  DateTime tripStart = DateTime.now();
  double distanceKm = 0;
  double maxKmh = 0;
  Duration moving = Duration.zero;
  double? zeroTo100; // seconds of the best 0→100 run this trip
  DateTime? _launch;
  double? _lastLat, _lastLng;
  DateTime? _lastT;

  double get avgKmh => moving.inSeconds < 5 ? 0 : distanceKm / (moving.inSeconds / 3600);
  Duration get tripTime => DateTime.now().difference(tripStart);

  String get compass {
    if (heading < 0) return '—';
    const dirs = ['شمال', 'شمال شرق', 'شرق', 'جنوب شرق', 'جنوب', 'جنوب غرب', 'غرب', 'شمال غرب'];
    return dirs[((heading + 22.5) % 360 ~/ 45)];
  }

  void resetTrip() {
    tripStart = DateTime.now();
    distanceKm = 0;
    maxKmh = 0;
    moving = Duration.zero;
    zeroTo100 = null;
    _launch = null;
    notifyListeners();
  }

  /// Ref-counted: the dashboard calls start() in initState and stop() in dispose.
  Future<void> start() async {
    _listeners++;
    if (_sub != null) return;
    final p = await Permission.locationWhenInUse.request();
    if (!p.isGranted) {
      error = 'محتاج إذن الموقع علشان عداد السرعة';
      notifyListeners();
      return;
    }
    error = null;
    _sub = _ch.receiveBroadcastStream().listen(_onFix, onError: (e) {
      error = e is PlatformException ? (e.message ?? 'GPS') : 'GPS';
      notifyListeners();
    });
  }

  void stop() {
    _listeners = math.max(0, _listeners - 1);
    if (_listeners > 0) return;
    _sub?.cancel();
    _sub = null;
  }

  void _onFix(dynamic e) {
    final m = Map<String, dynamic>.from(e as Map);
    if ((m['provider'] ?? '') == 'network' && hasFix && lastFix != null &&
        DateTime.now().difference(lastFix!).inSeconds < 5) {
      return; // prefer GPS fixes while we have them
    }
    final now = DateTime.now();
    final sp = (m['speed'] as num).toDouble();
    rawKmh = sp < 0 ? 0 : sp * 3.6;
    if (rawKmh < 1.5) rawKmh = 0; // GPS jitter while parked
    speedKmh = speedKmh + (rawKmh - speedKmh) * 0.55;
    if (speedKmh < 0.5) speedKmh = 0;
    heading = (m['bearing'] as num).toDouble();
    altitude = (m['alt'] as num).toDouble();
    accuracy = (m['acc'] as num).toDouble();
    sats = (m['sats'] as num?)?.toInt() ?? 0;
    satsUsed = (m['used'] as num?)?.toInt() ?? 0;
    hasFix = true;
    error = null;
    lastFix = now;

    final lat = (m['lat'] as num).toDouble();
    final lng = (m['lng'] as num).toDouble();
    if (_lastLat != null && _lastT != null && rawKmh > 2 && (accuracy < 0 || accuracy < 35)) {
      final d = _haversine(_lastLat!, _lastLng!, lat, lng);
      final dt = now.difference(_lastT!);
      if (d < 0.5) {
        distanceKm += d;
        moving += dt;
      }
    }
    _lastLat = lat;
    _lastLng = lng;
    _lastT = now;
    if (rawKmh > maxKmh) maxKmh = rawKmh;

    // 0 → 100 km/h timer
    if (rawKmh < 3) {
      _launch = null;
    } else if (_launch == null && rawKmh < 15) {
      _launch = now;
    } else if (_launch != null && rawKmh >= 100) {
      final s = now.difference(_launch!).inMilliseconds / 1000;
      if (s > 3 && (zeroTo100 == null || s < zeroTo100!)) zeroTo100 = s;
      _launch = null;
    }
    notifyListeners();
  }

  static double _haversine(double la1, double lo1, double la2, double lo2) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLa = rad(la2 - la1), dLo = rad(lo2 - lo1);
    final a = math.sin(dLa / 2) * math.sin(dLa / 2) +
        math.cos(rad(la1)) * math.cos(rad(la2)) * math.sin(dLo / 2) * math.sin(dLo / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }
}
