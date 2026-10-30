import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/reciters.dart';

/// One recitation (moshaf) of a reciter on an mp3quran-style server.
class Moshaf {
  final String name;
  final String server; // ends with '/'
  final Set<int> surahs;

  Moshaf({required this.name, required String server, required this.surahs})
      : server = server.endsWith('/') ? server : '$server/';

  String urlFor(int surah) =>
      '$server${surah.toString().padLeft(3, '0')}.mp3';

  bool get isMujawwad => name.contains('مجود');

  Map<String, dynamic> toJson() =>
      {'name': name, 'server': server, 'surahs': surahs.toList()..sort()};

  factory Moshaf.fromJson(Map<String, dynamic> j) => Moshaf(
        name: j['name'] as String,
        server: j['server'] as String,
        surahs: (j['surahs'] as List).map((e) => e as int).toSet(),
      );

  static Set<int> all() => {for (var i = 1; i <= 114; i++) i};
}

String normalizeArabic(String s) {
  var out = s
      .replaceAll(RegExp('[ً-ْٰـ]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي');
  out = out.replaceAll(RegExp(r'[^ء-يa-zA-Z0-9]'), '');
  return out.toLowerCase();
}

/// Resolves every reciter in [reciters] against the public mp3quran.net API.
/// Returns reciterId -> list of recitations, best one first.
class Mp3QuranResolver {
  static const endpoint =
      'https://www.mp3quran.net/api/v3/reciters?language=ar';

  static Future<Map<String, List<Moshaf>>> resolve() async {
    final res = await http
        .get(Uri.parse(endpoint))
        .timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final list = (data['reciters'] as List).cast<Map<String, dynamic>>();

    final out = <String, List<Moshaf>>{};
    for (final r in reciters) {
      final tokens = r.tokens.map(normalizeArabic).toList();
      final found = <Moshaf>[];
      for (final api in list) {
        final n = normalizeArabic('${api['name']}');
        if (!tokens.every(n.contains)) continue;
        for (final m in (api['moshaf'] as List? ?? const [])) {
          final mm = m as Map<String, dynamic>;
          final server = mm['server'] as String?;
          if (server == null || server.isEmpty) continue;
          final surahList = '${mm['surah_list'] ?? ''}'
              .split(',')
              .map((e) => int.tryParse(e.trim()))
              .whereType<int>()
              .where((e) => e >= 1 && e <= 114)
              .toSet();
          found.add(Moshaf(
            name: '${mm['name'] ?? 'تلاوة'}',
            server: server,
            surahs: surahList.isEmpty ? Moshaf.all() : surahList,
          ));
        }
      }
      if (found.isEmpty) continue;
      double score(Moshaf m) =>
          (m.name.contains('حفص') ? 2 : 0) +
          (m.name.contains(r.prefer) ? 3 : 0) +
          m.surahs.length / 114.0;
      found.sort((a, b) => score(b).compareTo(score(a)));
      // de-duplicate servers
      final seen = <String>{};
      out[r.id] = found.where((m) => seen.add(m.server)).toList();
    }
    return out;
  }
}
