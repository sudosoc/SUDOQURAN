import 'package:flutter/services.dart';

/// Pushes "now playing" to the native home-screen widget (no extra plugins).
class HomeWidgetBridge {
  static const _ch = MethodChannel('sudoquran/widget');
  static String _last = '';

  static Future<void> update(String title, String subtitle, bool playing) async {
    final sig = '$title|$subtitle|$playing';
    if (sig == _last) return;
    _last = sig;
    try {
      await _ch.invokeMethod('update', {
        'title': title.isEmpty ? 'القرآن الكريم' : title,
        'subtitle': subtitle.isEmpty ? 'اضغط للتشغيل' : subtitle,
        'playing': playing,
      });
    } catch (_) {
      _last = '';
    }
  }
}
