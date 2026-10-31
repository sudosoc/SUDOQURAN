import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  Settings._();
  static final Settings instance = Settings._();

  late SharedPreferences _p;

  bool allowStreaming = true;
  bool autoResume = true;

  /// Keep downloading missing audio whenever the app opens.
  bool autoDownload = false;

  /// Selected colour theme.
  String themeId = 'emerald';

  /// Custom theme colours: [background, surface, accent, secondary] (ARGB ints).
  List<int> customColors = [0xFF000000, 0xFF1A0507, 0xFFE5484D, 0xFF9B111E];

  /// Open straight into driving mode when the app starts.
  bool driveOnLaunch = false;

  /// Everything newer lives in one JSON map (keeps this file small).
  Map<String, dynamic> extra = {};

  T _opt<T>(String k, T def) {
    final v = extra[k];
    if (v == null) return def;
    if (def is double && v is num) return v.toDouble() as T;
    return v is T ? v : def;
  }

  Future<void> setOpt(String k, Object? v) async {
    if (v == null) {
      extra.remove(k);
    } else {
      extra[k] = v;
    }
    await _p.setString('extra', jsonEncode(extra));
    notifyListeners();
  }

  // ---- interface
  double get uiScale => _opt('uiScale', 1.0);
  double get blur => _opt('blur', 22.0);
  bool get pattern => _opt('pattern', true);
  bool get animations => _opt('animations', true);
  String get playerSide => _opt('playerSide', 'left'); // left = driver side (LHD)
  bool get clock24 => _opt('clock24', false);

  // ---- drive mode
  String get driveStyle => _opt('driveStyle', 'luxury');

  // ---- widget
  String get widgetStyle => _opt('widgetStyle', 'glass');

  // ---- travel du'a (دعاء الركوب)
  bool get duaEnabled => _opt('duaEnabled', true);
  String get duaSource => _opt('duaSource', 'ayat:maher'); // ayat:<reciterId> | url:<url>

  // ---- prayer
  bool get prayerEnabled => _opt('prayerEnabled', true);
  String get prayerCity => _opt('prayerCity', 'tenth');
  bool get adhanSound => _opt('adhanSound', true);
  String? get adhanUrl => extra['adhanUrl'] as String?;
  bool get resumeAfterAdhan => _opt('resumeAfterAdhan', true);

  /// Signature of everything that needs a full UI rebuild.
  String get uiSig => '$uiScale|$blur|$pattern|$animations|$playerSide';

  /// Last thing that was playing, used for "continue" and auto-resume.
  Map<String, dynamic>? lastSession;


  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    allowStreaming = _p.getBool('allowStreaming') ?? true;
    autoResume = _p.getBool('autoResume') ?? true;
    autoDownload = _p.getBool('autoDownload') ?? false;
    themeId = _p.getString('themeId') ?? 'emerald';
    driveOnLaunch = _p.getBool('driveOnLaunch') ?? false;
    final cc = _p.getStringList('customColors');
    if (cc != null && cc.length == 4) customColors = cc.map(int.parse).toList();
    try {
      extra = Map<String, dynamic>.from(jsonDecode(_p.getString('extra') ?? '{}') as Map);
    } catch (_) {}
    final ls = _p.getString('lastSession');
    if (ls != null) {
      try {
        lastSession = Map<String, dynamic>.from(jsonDecode(ls) as Map);
      } catch (_) {}
    }
  }

  Future<void> setAllowStreaming(bool v) async {
    allowStreaming = v;
    await _p.setBool('allowStreaming', v);
    notifyListeners();
  }

  Future<void> setAutoResume(bool v) async {
    autoResume = v;
    await _p.setBool('autoResume', v);
    notifyListeners();
  }

  Future<void> setAutoDownload(bool v) async {
    autoDownload = v;
    await _p.setBool('autoDownload', v);
    notifyListeners();
  }

  Future<void> setTheme(String id) async {
    themeId = id;
    await _p.setString('themeId', id);
    notifyListeners();
  }

  Future<void> setCustomColors(List<int> c) async {
    customColors = List.of(c);
    await _p.setStringList('customColors', c.map((e) => '$e').toList());
    if (themeId == 'custom') notifyListeners();
  }

  Future<void> setDriveOnLaunch(bool v) async {
    driveOnLaunch = v;
    await _p.setBool('driveOnLaunch', v);
    notifyListeners();
  }

  Future<void> saveSession(Map<String, dynamic> s) async {
    lastSession = s;
    await _p.setString('lastSession', jsonEncode(s));
  }
}
