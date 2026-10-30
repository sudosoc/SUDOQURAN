import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../data/reciters.dart';
import '../data/ruqyah.dart';
import 'settings.dart';
import 'sources.dart';

const audioExts = {'.mp3', '.m4a', '.aac', '.ogg', '.opus'};

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

  double get fraction => total == 0
      ? 1.0
      : ((done + failed + currentProgress) / total).clamp(0.0, 1.0).toDouble();
}

class _Item {
  final List<String> urls; // tried in order until one works
  final File dest;
  _Item(this.urls, this.dest);
}

/// Owns everything on disk and the download queue.
class Library extends ChangeNotifier {
  Library._();
  static final Library instance = Library._();

  late Directory root;
  final Map<String, Set<int>> _localCache = {};
  final Map<String, DownloadJob> jobs = {};
  final http.Client _client = http.Client();

  /// "Download everything" queue state.
  bool everythingRunning = false;
  String? everythingCurrent;
  bool _stopEverything = false;

  Future<void> init() async {
    Directory? base;
    if (Platform.isAndroid) base = await getExternalStorageDirectory();
    base ??= await getApplicationDocumentsDirectory();
    root = Directory('${base.path}/sudoquran');
    await root.create(recursive: true);
  }

  void refresh() => notifyListeners();

  // --------------------------------------------------------------- paths
  Directory reciterDir(Reciter r) => Directory('${root.path}/quran/${r.id}');
  Directory ruqyahAyatDir(RuqyahSheikh s) =>
      Directory('${root.path}/ruqyah/${s.id}/ayat');
  Directory ruqyahTracksDir(RuqyahSheikh s) =>
      Directory('${root.path}/ruqyah/${s.id}/tracks');

  // ------------------------------------------------------------- reciters
  Set<int> available(Reciter r) => Sources.instance.available(r.id);

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
      if (n >= 1 && n <= 114) out.add(n);
    }
    return out;
  }

  File? localFile(Reciter r, int n) {
    if (!localSurahs(r).contains(n)) return null;
    final f = File('${reciterDir(r).path}/${n.toString().padLeft(3, '0')}.mp3');
    return f.existsSync() ? f : null;
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

  bool reciterComplete(Reciter r) {
    final av = available(r);
    return av.isNotEmpty && localSurahs(r).containsAll(av);
  }

  // --------------------------------------------------------------- ruqyah
  Directory azkarDir(String ownerId) => Directory('${root.path}/azkar/$ownerId');
  Directory get photosDir => Directory('${root.path}/photos');

  File? photoFor(String id) {
    final f = File('${photosDir.path}/$id.img');
    return f.existsSync() ? f : null;
  }

  Future<void> setPhoto(String id, String sourcePath) async {
    await photosDir.create(recursive: true);
    await File(sourcePath).copy('${photosDir.path}/$id.img');
    PaintingBinding.instance.imageCache.clear();
    notifyListeners();
  }

  Future<void> removePhoto(String id) async {
    photoFor(id)?.deleteSync();
    PaintingBinding.instance.imageCache.clear();
    notifyListeners();
  }

  File? localIn(Directory dir, RemoteTrack t) {
    final f = File('${dir.path}/${trackFileName(t)}');
    return f.existsSync() ? f : null;
  }

  String azkarKey(String ownerId) => 'azkar_$ownerId';

  Future<DownloadJob?> downloadAzkar(String ownerId) async {
    final key = azkarKey(ownerId);
    if (isDownloading(key)) return jobs[key];
    final dir = azkarDir(ownerId);
    await dir.create(recursive: true);
    final all = [
      ...Sources.instance.azkarTracks(ownerId, 'morning'),
      ...Sources.instance.azkarTracks(ownerId, 'evening'),
    ];
    final seen = <String>{};
    final items = [
      for (final t in all)
        if (seen.add(t.url) && localIn(dir, t) == null)
          _Item([t.url], File('${dir.path}/${trackFileName(t)}'))
    ];
    return _run(key, items);
  }

  List<String> get azkarOwners => {
        ...Sources.instance.azkarOwners('morning'),
        ...Sources.instance.azkarOwners('evening'),
      }.toList();

  bool azkarComplete(String ownerId) {
    final dir = azkarDir(ownerId);
    final all = [
      ...Sources.instance.azkarTracks(ownerId, 'morning'),
      ...Sources.instance.azkarTracks(ownerId, 'evening'),
    ];
    return all.isNotEmpty && all.every((t) => localIn(dir, t) != null);
  }

  bool ruqyahComplete(RuqyahSheikh s) {
    final tracks = Sources.instance.ruqyahTracks(s.id);
    final tracksOk = tracks.every((t) => localTrack(s, t) != null);
    final ayatOk = s.everyAyahFolder == null || ruqyahAyatFiles(s).length >= ruqyahAyatCount;
    return tracksOk && ayatOk;
  }

  Future<void> deleteDir(Directory dir) async {
    if (dir.existsSync()) await dir.delete(recursive: true);
    _localCache.remove(dir.path);
    notifyListeners();
  }

  Future<int> dirSize(Directory dir) async {
    if (!dir.existsSync()) return 0;
    var total = 0;
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      if (e is File) {
        try {
          total += await e.length();
        } catch (_) {}
      }
    }
    return total;
  }

  String trackFileName(RemoteTrack t) {
    var name = Uri.decodeComponent(Uri.parse(t.url).pathSegments.last);
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (!audioExts.contains(_ext(name))) name = '$name.mp3';
    return name;
  }

  File? localTrack(RuqyahSheikh s, RemoteTrack t) {
    final f = File('${ruqyahTracksDir(s).path}/${trackFileName(t)}');
    return f.existsSync() ? f : null;
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

  // ------------------------------------------------------------- download
  bool isDownloading(String key) => jobs[key] != null && !jobs[key]!.finished;

  void cancel(String key) {
    jobs[key]?.cancelled = true;
    notifyListeners();
  }

  Future<DownloadJob?> downloadReciter(Reciter r, {Iterable<int>? only}) async {
    if (isDownloading(r.id)) return jobs[r.id];
    final dir = reciterDir(r);
    await dir.create(recursive: true);
    final have = localSurahs(r);
    final wanted = (only ?? available(r))
        .where((n) => !have.contains(n) && Sources.instance.urlsFor(r.id, n).isNotEmpty)
        .toList()
      ..sort();
    final items = [
      for (final n in wanted)
        _Item(Sources.instance.urlsFor(r.id, n),
            File('${dir.path}/${n.toString().padLeft(3, '0')}.mp3'))
    ];
    return _run(r.id, items, onEach: () => _invalidate(dir));
  }

  String ayatKey(RuqyahSheikh s) => 'ayat_${s.id}';
  String tracksKey(RuqyahSheikh s) => 'tracks_${s.id}';

  Future<DownloadJob?> downloadRuqyahAyat(RuqyahSheikh s) async {
    final folder = s.everyAyahFolder;
    if (folder == null) return null;
    if (isDownloading(ayatKey(s))) return jobs[ayatKey(s)];
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
        items.add(_Item([
          'https://everyayah.com/data/$folder/$name',
          'https://mirrors.quranicaudio.com/everyayah/$folder/$name',
        ], f));
      }
    }
    return _run(ayatKey(s), items);
  }

  Future<DownloadJob?> downloadRuqyahTracks(RuqyahSheikh s) async {
    if (isDownloading(tracksKey(s))) return jobs[tracksKey(s)];
    final dir = ruqyahTracksDir(s);
    await dir.create(recursive: true);
    final items = [
      for (final t in Sources.instance.ruqyahTracks(s.id))
        if (localTrack(s, t) == null)
          _Item([t.url], File('${dir.path}/${trackFileName(t)}'))
    ];
    return _run(tracksKey(s), items);
  }

  /// Downloads every reciter and both ruqyah sets, one after another.
  /// Resumable: already-downloaded files are skipped.
  Future<void> downloadEverything() async {
    if (everythingRunning) return;
    everythingRunning = true;
    _stopEverything = false;
    await Settings.instance.setAutoDownload(true);
    notifyListeners();
    try {
      for (final s in ruqyahSheikhs) {
        if (_stopEverything) break;
        everythingCurrent = 'الرقية — ${s.name}';
        notifyListeners();
        if (s.everyAyahFolder != null) await downloadRuqyahAyat(s);
        if (_stopEverything) break;
        await downloadRuqyahTracks(s);
      }
      for (final id in azkarOwners) {
        if (_stopEverything) break;
        everythingCurrent = 'الأذكار';
        notifyListeners();
        await downloadAzkar(id);
      }
      for (final r in reciters) {
        if (_stopEverything) break;
        if (reciterComplete(r) || available(r).isEmpty) continue;
        everythingCurrent = r.name;
        notifyListeners();
        await downloadReciter(r);
      }
      if (!_stopEverything) await Settings.instance.setAutoDownload(false);
    } finally {
      everythingRunning = false;
      everythingCurrent = null;
      notifyListeners();
    }
  }

  /// Runs [tasks] one after another under the "everything" banner.
  Future<void> runQueue(String label, List<Future<void> Function()> tasks) async {
    if (everythingRunning) return;
    everythingRunning = true;
    _stopEverything = false;
    everythingCurrent = label;
    notifyListeners();
    try {
      for (final t in tasks) {
        if (_stopEverything) break;
        await t();
      }
    } finally {
      everythingRunning = false;
      everythingCurrent = null;
      notifyListeners();
    }
  }

  Future<void> downloadAllQuran() => runQueue('القرآن لكل الشيوخ', [
        for (final r in reciters)
          () async {
            everythingCurrent = r.name;
            notifyListeners();
            await downloadReciter(r);
          }
      ]);

  Future<void> downloadAllRuqyah() => runQueue('الرقية', [
        for (final s in ruqyahSheikhs) ...[
          if (s.everyAyahFolder != null) () => downloadRuqyahAyat(s),
          () => downloadRuqyahTracks(s),
        ]
      ]);

  Future<void> downloadAllAzkar() => runQueue('الأذكار', [
        for (final id in azkarOwners) () => downloadAzkar(id),
      ]);

  Future<void> stopEverything() async {
    _stopEverything = true;
    for (final j in jobs.values) {
      j.cancelled = true;
    }
    await Settings.instance.setAutoDownload(false);
    notifyListeners();
  }

  Future<DownloadJob> _run(String key, List<_Item> items, {VoidCallback? onEach}) async {
    final job = DownloadJob(key, items.length);
    jobs[key] = job;
    notifyListeners();

    var lastNotify = DateTime.now();
    var cursor = 0;
    Future<void> worker() async {
      while (!job.cancelled && cursor < items.length) {
        final item = items[cursor++];
        var ok = false;
        for (final url in item.urls) {
          if (job.cancelled) break;
          try {
            await _downloadFile(url, item.dest, job, (p) {
              job.currentProgress = p;
              final now = DateTime.now();
              if (now.difference(lastNotify).inMilliseconds > 500) {
                lastNotify = now;
                notifyListeners();
              }
            });
            ok = true;
            break;
          } catch (_) {
            // try next mirror
          }
        }
        if (job.cancelled) break;
        ok ? job.done++ : job.failed++;
        job.currentProgress = 0;
        onEach?.call();
        notifyListeners();
      }
    }

    await Future.wait([worker(), worker(), worker()]);
    job.finished = true;
    notifyListeners();
    return job;
  }

  Future<void> _downloadFile(
      String url, File dest, DownloadJob job, void Function(double) onProgress) async {
    final part = File('${dest.path}.part');
    final res = await _client
        .send(http.Request('GET', Uri.parse(url)))
        .timeout(const Duration(seconds: 30));
    final ct = (res.headers['content-type'] ?? '').toLowerCase();
    if (res.statusCode != 200 || ct.contains('text/html')) {
      await res.stream.drain<void>();
      throw HttpException('HTTP ${res.statusCode} $ct');
    }
    final total = res.contentLength ?? 0;
    var got = 0;
    final sink = part.openWrite();
    try {
      await for (final chunk in res.stream.timeout(const Duration(seconds: 45))) {
        if (job.cancelled) throw const HttpException('cancelled');
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress(got / total);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (got < 10000 || (total > 0 && got < total)) {
      if (part.existsSync()) await part.delete();
      throw const HttpException('incomplete');
    }
    await part.rename(dest.path);
  }

  // -------------------------------------------------------------- storage
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
