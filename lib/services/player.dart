import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../data/reciters.dart';
import '../data/ruqyah.dart';
import '../data/surahs.dart';
import 'library.dart';
import 'settings.dart';
import 'sources.dart';

enum PlayKind { none, quran, ruqyahAyat, ruqyahTracks }

class Player extends ChangeNotifier {
  Player._();
  static final Player instance = Player._();

  final AudioPlayer audio = AudioPlayer();

  PlayKind kind = PlayKind.none;
  String? reciterId;
  String? sheikhId;
  List<int> _surahOrder = [];

  String title = '';
  String subtitle = '';
  String? artLetters;
  int? currentSurah;

  Timer? _saveTimer;

  Future<void> init() async {
    audio.sequenceStateStream.listen((state) {
      final tag = state?.currentSource?.tag;
      if (tag is MediaItem) {
        title = tag.title;
        subtitle = tag.artist ?? '';
        final extras = tag.extras ?? const {};
        currentSurah = extras['surah'] as int?;
      }
      notifyListeners();
      _save();
    });
    audio.playerStateStream.listen((_) => notifyListeners());
    audio.loopModeStream.listen((_) => notifyListeners());
    _saveTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (audio.playing) _save();
    });

    final s = Settings.instance.lastSession;
    if (s != null) {
      try {
        await _restore(s, autoplay: Settings.instance.autoResume);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    audio.dispose();
    super.dispose();
  }

  bool get hasMedia => kind != PlayKind.none;
  bool get playing => audio.playing;

  // ------------------------------------------------------------- quran
  /// Builds the playlist for [r] and starts at [surahNo].
  /// Returns false if that surah isn't playable (not local, no streaming).
  Future<bool> playQuran(Reciter r, int surahNo,
      {Duration position = Duration.zero, bool autoplay = true}) async {
    final lib = Library.instance;
    final stream = Settings.instance.allowStreaming;
    final order = <int>[];
    final sources = <AudioSource>[];
    for (var n = 1; n <= 114; n++) {
      final f = lib.localFile(r, n);
      final urls = Sources.instance.urlsFor(r.id, n);
      final item = MediaItem(
        id: 'q_${r.id}_$n',
        title: 'سورة ${surah(n).name}',
        artist: r.name,
        album: 'القرآن الكريم',
        extras: {'surah': n},
      );
      if (f != null) {
        order.add(n);
        sources.add(AudioSource.file(f.path, tag: item));
      } else if (stream && urls.isNotEmpty) {
        order.add(n);
        sources.add(AudioSource.uri(Uri.parse(urls.first), tag: item));
      }
    }
    final idx = order.indexOf(surahNo);
    if (idx < 0) return false;

    kind = PlayKind.quran;
    reciterId = r.id;
    sheikhId = null;
    artLetters = r.initials;
    _surahOrder = order;
    await audio.setAudioSource(
      ConcatenatingAudioSource(children: sources),
      initialIndex: idx,
      initialPosition: position,
    );
    if (autoplay) unawaited(audio.play());
    notifyListeners();
    return true;
  }

  // ------------------------------------------------------------ ruqyah
  Future<bool> playRuqyahAyat(RuqyahSheikh s,
      {int index = 0, Duration position = Duration.zero, bool autoplay = true}) async {
    final files = Library.instance.ruqyahAyatFiles(s);
    if (files.isEmpty) return false;
    final sources = <AudioSource>[
      for (var i = 0; i < files.length; i++)
        AudioSource.file(files[i].file.path,
            tag: MediaItem(
              id: 'ra_${s.id}_$i',
              title: files[i].range.label,
              artist: 'الرقية الشرعية — ${s.name}',
              album: 'الرقية الشرعية',
            )),
    ];
    kind = PlayKind.ruqyahAyat;
    sheikhId = s.id;
    reciterId = null;
    artLetters = 'رقية';
    await audio.setAudioSource(ConcatenatingAudioSource(children: sources),
        initialIndex: index.clamp(0, sources.length - 1).toInt(), initialPosition: position);
    if (audio.loopMode == LoopMode.off) await audio.setLoopMode(LoopMode.all);
    if (autoplay) unawaited(audio.play());
    notifyListeners();
    return true;
  }

  Future<bool> playRuqyahTracks(RuqyahSheikh s,
      {int index = 0, Duration position = Duration.zero, bool autoplay = true}) async {
    final lib = Library.instance;
    final stream = Settings.instance.allowStreaming;
    final sources = <AudioSource>[];
    final remote = Sources.instance.ruqyahTracks(s.id);
    var start = 0;
    for (var i = 0; i < remote.length; i++) {
      final t = remote[i];
      final f = lib.localTrack(s, t);
      if (f == null && !stream) continue;
      if (i == index) start = sources.length;
      final tag = MediaItem(
        id: 'rt_${s.id}_$i',
        title: t.title,
        artist: 'الرقية الشرعية — ${s.name}',
        album: 'الرقية الشرعية',
      );
      sources.add(f != null
          ? AudioSource.file(f.path, tag: tag)
          : AudioSource.uri(Uri.parse(t.url), tag: tag));
    }
    if (sources.isEmpty) return false;
    kind = PlayKind.ruqyahTracks;
    sheikhId = s.id;
    reciterId = null;
    artLetters = 'رقية';
    await audio.setAudioSource(ConcatenatingAudioSource(children: sources),
        initialIndex: start, initialPosition: position);
    if (autoplay) unawaited(audio.play());
    notifyListeners();
    return true;
  }

  static String trackTitle(File f) {
    var n = f.path.split(Platform.pathSeparator).last;
    final dot = n.lastIndexOf('.');
    if (dot > 0) n = n.substring(0, dot);
    return n.replaceAll('_', ' ');
  }

  // ---------------------------------------------------------- controls
  Future<void> toggle() async {
    if (!hasMedia) {
      await resumeLast();
      return;
    }
    audio.playing ? await audio.pause() : unawaited(audio.play());
  }

  Future<void> next() async {
    if (audio.hasNext) await audio.seekToNext();
  }

  Future<void> previous() async {
    if (audio.position.inSeconds > 5 || !audio.hasPrevious) {
      await audio.seek(Duration.zero);
    } else {
      await audio.seekToPrevious();
    }
  }

  Future<void> seekBy(int seconds) async {
    final d = audio.duration;
    var p = audio.position + Duration(seconds: seconds);
    if (p < Duration.zero) p = Duration.zero;
    if (d != null && p > d) p = d;
    await audio.seek(p);
  }

  Future<void> cycleLoop() async {
    const order = [LoopMode.off, LoopMode.all, LoopMode.one];
    final i = order.indexOf(audio.loopMode);
    await audio.setLoopMode(order[(i + 1) % order.length]);
  }

  // ------------------------------------------------------ persistence
  void _save() {
    if (kind == PlayKind.none) return;
    final idx = audio.currentIndex ?? 0;
    Settings.instance.saveSession({
      'kind': kind.name,
      'reciter': reciterId,
      'sheikh': sheikhId,
      'surah': kind == PlayKind.quran && idx < _surahOrder.length
          ? _surahOrder[idx]
          : null,
      'index': idx,
      'pos': audio.position.inMilliseconds,
      'title': title,
      'subtitle': subtitle,
    });
  }

  Future<bool> resumeLast() async {
    final s = Settings.instance.lastSession;
    if (s == null) return false;
    return _restore(s, autoplay: true);
  }

  Future<bool> _restore(Map<String, dynamic> s, {required bool autoplay}) async {
    final pos = Duration(milliseconds: (s['pos'] as int?) ?? 0);
    switch (s['kind']) {
      case 'quran':
        final r = reciterById(s['reciter'] as String?);
        final n = s['surah'] as int?;
        if (r == null || n == null) return false;
        return playQuran(r, n, position: pos, autoplay: autoplay);
      case 'ruqyahAyat':
        final sh = sheikhById(s['sheikh'] as String?);
        if (sh == null) return false;
        return playRuqyahAyat(sh,
            index: (s['index'] as int?) ?? 0, position: pos, autoplay: autoplay);
      case 'ruqyahTracks':
        final sh = sheikhById(s['sheikh'] as String?);
        if (sh == null) return false;
        return playRuqyahTracks(sh,
            index: (s['index'] as int?) ?? 0, position: pos, autoplay: autoplay);
    }
    return false;
  }
}
