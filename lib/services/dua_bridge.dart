import 'package:flutter/services.dart';

import 'library.dart';
import 'settings.dart';

/// Keeps the native background service (plays دعاء الركوب when the car starts)
/// in sync with the settings and the downloaded files.
class DuaBridge {
  static const _ch = MethodChannel('sudoquran/dua');
  static String _sig = '';
  static bool _triedDownload = false;

  static Future<void> sync() async {
    final st = Settings.instance;
    final lib = Library.instance;
    final files = lib.duaFiles().map((f) => f.path).toList();
    final enabled = st.duaEnabled && st.duaOnCarStart;
    if (enabled && !_triedDownload && files.length < lib.duaUrls().length && !lib.isDownloading('dua')) {
      _triedDownload = true; // once per run, so no loop when offline
      lib.downloadDua(); // first time: fetch it so it works offline
    }
    final sig = '$enabled|${files.join(',')}';
    if (sig == _sig) return;
    _sig = sig;
    try {
      await _ch.invokeMethod('configure', {'enabled': enabled && files.isNotEmpty, 'paths': files});
    } catch (_) {
      _sig = '';
    }
  }

  /// When the background service already played it (car just started).
  static Future<DateTime?> lastPlayed() async {
    // The channel is registered when the activity attaches; retry briefly.
    for (var i = 0; i < 4; i++) {
      try {
        final ms = await _ch.invokeMethod<int>('lastPlayed');
        if (ms == null || ms == 0) return null;
        return DateTime.fromMillisecondsSinceEpoch(ms);
      } on MissingPluginException {
        await Future<void>.delayed(const Duration(milliseconds: 700));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<void> test() async {
    try {
      await _ch.invokeMethod('test');
    } catch (_) {}
  }
}
