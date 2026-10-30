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

  /// Last thing that was playing, used for "continue" and auto-resume.
  Map<String, dynamic>? lastSession;


  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    allowStreaming = _p.getBool('allowStreaming') ?? true;
    autoResume = _p.getBool('autoResume') ?? true;
    autoDownload = _p.getBool('autoDownload') ?? false;
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

  Future<void> saveSession(Map<String, dynamic> s) async {
    lastSession = s;
    await _p.setString('lastSession', jsonEncode(s));
  }
}
