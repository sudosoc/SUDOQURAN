import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  Settings._();
  static final Settings instance = Settings._();

  late SharedPreferences _p;

  bool allowStreaming = true;
  bool autoResume = true;

  /// reciterId -> custom server URL (overrides the default recitation).
  Map<String, String> serverOverride = {};

  /// reciterId -> server URL of the chosen recitation (moshaf).
  Map<String, String> selectedVariant = {};

  /// Last thing that was playing, used for "continue" and auto-resume.
  Map<String, dynamic>? lastSession;

  /// Cached mp3quran resolution (json).
  String? moshafCache;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    allowStreaming = _p.getBool('allowStreaming') ?? true;
    autoResume = _p.getBool('autoResume') ?? true;
    serverOverride = _readMap('serverOverride');
    selectedVariant = _readMap('selectedVariant');
    moshafCache = _p.getString('moshafCache');
    final ls = _p.getString('lastSession');
    if (ls != null) {
      try {
        lastSession = Map<String, dynamic>.from(jsonDecode(ls) as Map);
      } catch (_) {}
    }
  }

  Map<String, String> _readMap(String key) {
    final raw = _p.getString(key);
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
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

  Future<void> setServerOverride(String reciterId, String? url) async {
    if (url == null || url.trim().isEmpty) {
      serverOverride.remove(reciterId);
    } else {
      var u = url.trim();
      if (!u.endsWith('/')) u = '$u/';
      serverOverride[reciterId] = u;
    }
    await _p.setString('serverOverride', jsonEncode(serverOverride));
    notifyListeners();
  }

  Future<void> setSelectedVariant(String reciterId, String server) async {
    selectedVariant[reciterId] = server;
    await _p.setString('selectedVariant', jsonEncode(selectedVariant));
    notifyListeners();
  }

  Future<void> setMoshafCache(String json) async {
    moshafCache = json;
    await _p.setString('moshafCache', json);
  }

  Future<void> saveSession(Map<String, dynamic> s) async {
    lastSession = s;
    await _p.setString('lastSession', jsonEncode(s));
  }
}
