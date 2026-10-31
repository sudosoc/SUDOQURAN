import 'package:flutter/services.dart';

import 'settings.dart';

/// Pushes "now playing" + the chosen style to the native home-screen widget.
class HomeWidgetBridge {
  static const _ch = MethodChannel('sudoquran/widget');
  static String _last = '';
  static String _title = 'القرآن الكريم';
  static String _subtitle = 'اضغط للتشغيل';
  static bool _playing = false;

  static Future<void> update(String title, String subtitle, bool playing) async {
    _title = title.isEmpty ? 'القرآن الكريم' : title;
    _subtitle = subtitle.isEmpty ? 'اضغط للتشغيل' : subtitle;
    _playing = playing;
    await _send();
  }

  static Future<void> refresh() {
    _last = '';
    return _send();
  }

  static Future<void> _send() async {
    final style = Settings.instance.widgetStyle;
    final sig = '$_title|$_subtitle|$_playing|$style';
    if (sig == _last) return;
    _last = sig;
    try {
      await _ch.invokeMethod('update', {
        'title': _title,
        'subtitle': _subtitle,
        'playing': _playing,
        'style': style,
      });
    } catch (_) {
      _last = '';
    }
  }
}
