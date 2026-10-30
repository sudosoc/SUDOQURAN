import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RemoteTrack {
  final String title;
  final String url;
  final int size;
  const RemoteTrack(this.title, this.url, this.size);
}

/// Audio links for every reciter / ruqyah sheikh.
///
/// The list is built and verified by `tool/build_sources.py` on GitHub
/// Actions (it searches mp3quran, quranicaudio and archive.org) and shipped
/// inside the APK. On start-up the app also pulls the latest copy from the
/// repo, so new links arrive without reinstalling.
class Sources extends ChangeNotifier {
  Sources._();
  static final Sources instance = Sources._();

  static const remoteUrl =
      'https://raw.githubusercontent.com/sudosoc/SUDOQURAN/main/assets/sources.json';

  Map<String, Map<int, List<String>>> _reciters = {};
  Map<String, List<RemoteTrack>> _ruqyah = {};
  Map<String, Map<String, List<RemoteTrack>>> _azkar = {};
  Map<String, String> labels = {};
  String? generated;
  bool refreshing = false;
  String? error;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final cached = p.getString('sourcesJson');
    String? bundled;
    try {
      bundled = await rootBundle.loadString('assets/sources.json');
    } catch (_) {}
    // Use whichever is newer.
    final candidates = [cached, bundled].whereType<String>().toList();
    String? best;
    String bestGen = '';
    for (final c in candidates) {
      try {
        final g = '${(jsonDecode(c) as Map)['generated'] ?? ''}';
        if (best == null || g.compareTo(bestGen) > 0) {
          best = c;
          bestGen = g;
        }
      } catch (_) {}
    }
    if (best != null) _parse(best);
  }

  Future<bool> refresh() async {
    if (refreshing) return false;
    refreshing = true;
    error = null;
    notifyListeners();
    try {
      final res = await http
          .get(Uri.parse(remoteUrl))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final body = utf8.decode(res.bodyBytes);
      _parse(body);
      final p = await SharedPreferences.getInstance();
      await p.setString('sourcesJson', body);
      return true;
    } catch (e) {
      error = 'مفيش نت — شغالين بالمصادر المحفوظة';
      return false;
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  void _parse(String body) {
    final j = jsonDecode(body) as Map<String, dynamic>;
    generated = j['generated'] as String?;
    final rec = <String, Map<int, List<String>>>{};
    (j['reciters'] as Map? ?? {}).forEach((id, surahs) {
      final m = <int, List<String>>{};
      (surahs as Map).forEach((n, urls) {
        final k = int.tryParse('$n');
        if (k != null) m[k] = (urls as List).map((e) => '$e').toList();
      });
      rec['$id'] = m;
    });
    final ru = <String, List<RemoteTrack>>{};
    (j['ruqyah'] as Map? ?? {}).forEach((id, list) {
      ru['$id'] = [
        for (final t in (list as List))
          RemoteTrack('${(t as Map)['title']}', '${t['url']}', (t['size'] as num?)?.toInt() ?? 0)
      ];
    });
    final az = <String, Map<String, List<RemoteTrack>>>{};
    (j['azkar'] as Map? ?? {}).forEach((id, byTime) {
      final m = <String, List<RemoteTrack>>{};
      (byTime as Map).forEach((when, list) {
        m['$when'] = [
          for (final t in (list as List))
            RemoteTrack('${(t as Map)['title']}', '${t['url']}', (t['size'] as num?)?.toInt() ?? 0)
        ];
      });
      az['$id'] = m;
    });
    _reciters = rec;
    _ruqyah = ru;
    _azkar = az;
    labels = Map<String, String>.from((j['labels'] as Map? ?? {})
        .map((k, v) => MapEntry('$k', '$v')));
    notifyListeners();
  }

  List<String> urlsFor(String reciterId, int surah) =>
      _reciters[reciterId]?[surah] ?? const [];

  Set<int> available(String reciterId) =>
      (_reciters[reciterId]?.keys ?? const <int>[]).toSet();

  List<RemoteTrack> ruqyahTracks(String sheikhId) =>
      _ruqyah[sheikhId] ?? const [];

  /// when: 'morning' | 'evening'
  List<RemoteTrack> azkarTracks(String ownerId, String when) =>
      _azkar[ownerId]?[when] ?? const [];

  /// Owners (reciter / sheikh ids) that have azkar for [when].
  List<String> azkarOwners(String when) => [
        for (final e in _azkar.entries)
          if ((e.value[when] ?? const []).isNotEmpty) e.key
      ];
}
