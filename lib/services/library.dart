import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/reciters.dart';
import '../data/ruqyah.dart';
import '../data/surahs.dart';
import 'mp3quran.dart';
import 'settings.dart';

const audioExts = {'.mp3', '.m4a', '.aac', '.ogg', '.opus', '.wav', '.flac'};

String _ext(String path) {
  final i = path.lastIndexOf('.');
  return i < 0 ? '' : path.substring(i).toLowerCase();
}

String _base(String path) => path.split(Platform.pathSeparator).last;

class DownloadJob {
  final String key;
  final int total;
  int done = 0;
  int failed = 0;
  double currentProgress = 0;
  bool cancelled = false;
  bool finished = false;
  DownloadJob(this.key, this.total);

  double get fraction =>
      total == 0 ? 1 : ((done + failed + currentProgress) / total).clamp(0.0, 1.0).toDouble();
}

class _Item {
  final String url;
  final File dest;
  _Item(this.url, this.dest);
}

/// Owns everything on disk: downloaded/imported surahs and ruqyah tracks,
/// plus the download queue.
class Library extends ChangeNotifier {
  Library._();
  static final Library instance = Library._();

  late Directory root;
  final Map<String, List<Moshaf>> _resolved = {};
  final Map<String, Set<int>> _localCache = {};
  final Map<String, DownloadJob> jobs = {};

  bool resolving = false;
  String? resolveError;
  DateTime? resolvedAt;

  final http.Client _client = http.Client();

  // ---------------------------------------------------------------- init
  Future<void> init() async {
    Directory? base;
    if (Platform.isAndroid) base = await getExternalStorageDirectory();
    base ??= await getApplicationDocumentsDirectory();
    root = Directory('${base.path}/sudoquran');
    await root.create(recursive: true);

    final cache = Settings.instance.moshafCache;
    if (cache != null) {
      try {
        final j = jsonDecode(cache) as Map<String, dynamic>;
        j.forEach((k, v) {
          _resolved[k] = (v as List)
              .map((e) => Moshaf.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        });
      } catch (_) {}
    }
    // Refresh the online catalogue in the background.
    unawaited(refreshCatalogue());
  }

  Future<void> refreshCatalogue() async {
    if (resolving) return;
    resolving = true;
    resolveError = null;
    notifyListeners();
    try {
      final res = await Mp3QuranResolver.resolve();
      if (res.isNotEmpty) {
        _resolved
          ..clear()
          ..addAll(res);
        await Settings.instance.setMoshafCache(jsonEncode(
            res.map((k, v) => MapEntry(k, v.map((m) => m.toJson()).toList()))));
        resolvedAt = DateTime.now();
      }
    } catch (e) {
      resolveError = 'تعذر الاتصال بالإنترنت';
    } finally {
      resolving = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------- moshafs
  List<Moshaf> moshafsFor(Reciter r) {
    final list = <Moshaf>[];
    final override = Settings.instance.serverOverride[r.id];
    if (override != null) {
      list.add(Moshaf(name: 'رابط مخصص', server: override, surahs: Moshaf.all()));
    }
    final resolved = _resolved[r.id];
    if (resolved != null && resolved.isNotEmpty) {
      list.addAll(resolved);
    } else if (r.fallbackServer != null) {
      list.add(Moshaf(
          name: 'حفص عن عاصم - مرتل',
          server: r.fallbackServer!,
          surahs: Moshaf.all()));
    }
    return list;
  }

  Moshaf? defaultMoshaf(Reciter r) {
    final l = moshafsFor(r);
    return l.isEmpty ? null : l.first;
  }

  Moshaf? activeMoshaf(Reciter r) {
    final l = moshafsFor(r);
    if (l.isEmpty) return null;
    final sel = Settings.instance.selectedVariant[r.id];
    for (final m in l) {
      if (m.server == sel) return m;
    }
    return l.first;
  }

  bool isOnline(Reciter r) => moshafsFor(r).isNotEmpty;

  void refresh() => notifyListeners();

  // --------------------------------------------------------------- paths
  String _folderKey(Reciter r, Moshaf? m) {
    final def = defaultMoshaf(r);
    if (m == null || def == null || m.server == def.server) return 'main';
    final uri = Uri.tryParse(m.server);
    final slug = (uri?.pathSegments.where((s) => s.isNotEmpty).join('_') ?? 'alt')
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '');
    return slug.isEmpty ? 'alt' : slug;
  }

  Directory reciterDir(Reciter r, [Moshaf? m]) =>
      Directory('${root.path}/quran/${r.id}/${_folderKey(r, m ?? activeMoshaf(r))}');

  Directory ruqyahAyatDir(RuqyahSheikh s) =>
      Directory('${root.path}/ruqyah/${s.id}/ayat');
  Directory ruqyahTracksDir(RuqyahSheikh s) =>
      Directory('${root.path}/ruqyah/${s.id}/tracks');

  // -------------------------------------------------------------- local
  Set<int> localSurahs(Reciter r) {
    final dir = reciterDir(r);
    return _localCache.putIfAbsent(dir.path, () => _scan(dir));
  }

  Set<int> _scan(Directory dir) {
    final out = <int>{};
    if (!dir.existsSync()) return out;
    final re = RegExp(r'^(\d{3})\.[A-Za-z0-9]+$');
    for (final f in dir.listSync().whereType<File>()) {
      final m = re.firstMatch(_base(f.path));
      if (m == null) continue;
      final n = int.parse(m.group(1)!);
      if (n >= 1 && n <= 114 && audioExts.contains(_ext(f.path))) out.add(n);
    }
    return out;
  }

  File? localFile(Reciter r, int n) {
    if (!localSurahs(r).contains(n)) return null;
    final dir = reciterDir(r);
    final p = n.toString().padLeft(3, '0');
    for (final e in audioExts) {
      final f = File('${dir.path}/$p$e');
      if (f.existsSync()) return f;
    }
    return null;
  }

  void _invalidate(Directory dir) {
    _localCache.remove(dir.path);
    notifyListeners();
  }

  Future<void> deleteReciter(Reciter r) async {
    final dir = reciterDir(r);
    if (dir.existsSync()) await dir.delete(recursive: true);
    _invalidate(dir);
  }

  List<File> ruqyahTracks(RuqyahSheikh s) {
    final dir = ruqyahTracksDir(s);
    if (!dir.existsSync()) return [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => audioExts.contains(_ext(f.path)))
        .toList()
      ..sort((a, b) => _base(a.path).compareTo(_base(b.path)));
    return files;
  }

  /// Ruqyah verse files present on disk, in recitation order.
  List<({AyahRange range, File file})> ruqyahAyatFiles(RuqyahSheikh s) {
    final dir = ruqyahAyatDir(s);
    final out = <({AyahRange range, File file})>[];
    if (!dir.existsSync()) return out;
    for (final r in ruqyahAyat) {
      for (final a in r.ayat) {
        final f = File('${dir.path}/${ayahFileName(r.surah, a)}');
        if (f.existsSync()) out.add((range: r, file: f));
      }
    }
    return out;
  }

  Future<void> deleteRuqyahTrack(File f) async {
    if (f.existsSync()) await f.delete();
    notifyListeners();
  }

  // ------------------------------------------------------------ download
  bool isDownloading(String key) =>
      jobs[key] != null && !jobs[key]!.finished;

  void cancel(String key) {
    jobs[key]?.cancelled = true;
    notifyListeners();
  }

  /// Download surahs of the active recitation. [only] limits to some surahs.
  Future<DownloadJob?> downloadReciter(Reciter r, {Iterable<int>? only}) async {
    final m = activeMoshaf(r);
    if (m == null || isDownloading(r.id)) return null;
    final dir = reciterDir(r, m);
    await dir.create(recursive: true);
    final have = localSurahs(r);
    final wanted = (only ?? m.surahs).where((n) => m.surahs.contains(n) && !have.contains(n)).toList()
      ..sort();
    final items = [
      for (final n in wanted)
        _Item(m.urlFor(n), File('${dir.path}/${n.toString().padLeft(3, '0')}.mp3'))
    ];
    return _run(r.id, items, onEach: () => _invalidate(dir));
  }

  Future<DownloadJob?> downloadRuqyahAyat(RuqyahSheikh s) async {
    final folder = s.everyAyahFolder;
    if (folder == null || isDownloading('ruqyah_${s.id}')) return null;
    final dir = ruqyahAyatDir(s);
    await dir.create(recursive: true);
    final items = <_Item>[];
    final seen = <String>{};
    for (final r in ruqyahAyat) {
      for (final a in r.ayat) {
        final name = ayahFileName(r.surah, a);
        if (!seen.add(name)) continue;
        final f = File('${dir.path}/$name');
        if (f.existsSync()) continue;
        items.add(_Item('https://everyayah.com/data/$folder/$name', f));
      }
    }
    return _run('ruqyah_${s.id}', items);
  }

  Future<DownloadJob?> downloadRuqyahUrl(RuqyahSheikh s, String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) return null;
    final dir = ruqyahTracksDir(s);
    await dir.create(recursive: true);
    var name = uri.pathSegments.isNotEmpty
        ? Uri.decodeComponent(uri.pathSegments.last)
        : '';
    if (!audioExts.contains(_ext(name))) {
      name = 'رقية_${DateTime.now().millisecondsSinceEpoch}.mp3';
    }
    return _run('ruqyahurl_${s.id}', [_Item(uri.toString(), File('${dir.path}/$name'))]);
  }

  Future<DownloadJob> _run(String key, List<_Item> items,
      {VoidCallback? onEach}) async {
    final job = DownloadJob(key, items.length);
    jobs[key] = job;
    notifyListeners();

    var lastNotify = DateTime.now();
    var cursor = 0;
    Future<void> worker() async {
      while (!job.cancelled) {
        if (cursor >= items.length) break;
        final item = items[cursor++];
        try {
          await _downloadFile(item, job, (p) {
            job.currentProgress = p;
            final now = DateTime.now();
            if (now.difference(lastNotify).inMilliseconds > 400) {
              lastNotify = now;
              notifyListeners();
            }
          });
          job.done++;
        } catch (_) {
          job.failed++;
        }
        job.currentProgress = 0;
        onEach?.call();
        notifyListeners();
      }
    }

    await Future.wait([worker(), worker()]);
    job.finished = true;
    notifyListeners();
    return job;
  }

  Future<void> _downloadFile(
      _Item item, DownloadJob job, void Function(double) onProgress) async {
    final part = File('${item.dest.path}.part');
    final req = http.Request('GET', Uri.parse(item.url));
    final res = await _client.send(req).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}');
    }
    final total = res.contentLength ?? 0;
    var got = 0;
    final sink = part.openWrite();
    try {
      await for (final chunk in res.stream.timeout(const Duration(seconds: 40))) {
        if (job.cancelled) throw const HttpException('cancelled');
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress(got / total);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (job.cancelled) {
      if (part.existsSync()) await part.delete();
      return;
    }
    await part.rename(item.dest.path);
  }

  // -------------------------------------------------------------- import
  static Future<bool> ensureAudioPermission() async {
    if (!Platform.isAndroid) return true;
    if ((await Permission.audio.request()).isGranted) return true;
    return (await Permission.storage.request()).isGranted;
  }

  /// Collect audio files from a folder (and one level of sub-folders).
  List<File> _collect(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return [];
    final out = <File>[];
    for (final e in dir.listSync()) {
      if (e is File && audioExts.contains(_ext(e.path))) out.add(e);
      if (e is Directory) {
        try {
          out.addAll(e
              .listSync()
              .whereType<File>()
              .where((f) => audioExts.contains(_ext(f.path))));
        } catch (_) {}
      }
    }
    return out;
  }

  /// Works out which surah a file is, from "001.mp3", "18 الكهف.mp3",
  /// "سورة الكهف - ماهر.mp3", ...
  static int? detectSurah(String fileName) {
    final noExt = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    for (final m in RegExp(r'(?<!\d)(\d{1,3})(?!\d)').allMatches(noExt)) {
      final n = int.parse(m.group(1)!);
      if (n >= 1 && n <= 114) return n;
    }
    final norm = normalizeArabic(noExt);
    SurahInfo? best;
    for (final s in surahs) {
      final sn = normalizeArabic(s.name);
      if (sn.length < 3) continue; // ق، ص، طه، يس are too ambiguous
      if (norm.contains(sn) && (best == null || sn.length > normalizeArabic(best.name).length)) {
        best = s;
      }
    }
    return best?.number;
  }

  /// Copies audio files into the active recitation folder of [r].
  /// Returns (imported, skipped).
  Future<(int, int)> importToReciter(Reciter r,
      {String? folder, List<String>? files}) async {
    final list = <File>[
      if (folder != null) ..._collect(folder),
      if (files != null) ...files.map(File.new),
    ];
    final dir = reciterDir(r);
    await dir.create(recursive: true);
    var ok = 0, skip = 0;
    for (final f in list) {
      final n = detectSurah(_base(f.path));
      if (n == null) {
        skip++;
        continue;
      }
      final p = n.toString().padLeft(3, '0');
      // remove any other format of the same surah
      for (final e in audioExts) {
        final old = File('${dir.path}/$p$e');
        if (old.existsSync()) await old.delete();
      }
      try {
        await f.copy('${dir.path}/$p${_ext(f.path)}');
        ok++;
      } catch (_) {
        skip++;
      }
    }
    _invalidate(dir);
    return (ok, skip);
  }

  Future<int> importToRuqyah(RuqyahSheikh s,
      {String? folder, List<String>? files}) async {
    final list = <File>[
      if (folder != null) ..._collect(folder),
      if (files != null) ...files.map(File.new),
    ];
    final dir = ruqyahTracksDir(s);
    await dir.create(recursive: true);
    var ok = 0;
    for (final f in list) {
      try {
        await f.copy('${dir.path}/${_base(f.path)}');
        ok++;
      } catch (_) {}
    }
    notifyListeners();
    return ok;
  }

  // ------------------------------------------------------------- storage
  Future<int> usedBytes() async {
    var total = 0;
    if (!root.existsSync()) return 0;
    await for (final e in root.list(recursive: true, followLinks: false)) {
      if (e is File) {
        try {
          total += await e.length();
        } catch (_) {}
      }
    }
    return total;
  }
}

String formatBytes(int b) {
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(0)} MB';
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}
