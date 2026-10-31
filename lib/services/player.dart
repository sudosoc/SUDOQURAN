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
import 'dua_bridge.dart';
import 'sources.dart';
import 'widget_bridge.dart';

enum PlayKind { none, quran, ruqyahAyat, ruqyahTracks, azkar, radio, special }

class Player extends ChangeNotifier {
  Player._();
  static final Player instance = Player._();

  final AudioPlayer audio = AudioPlayer();

  PlayKind kind = PlayKind.none;
  String? reciterId;
  String? sheikhId;
  String? azkarOwner;
  String? azkarWhen;
  String? radioId;
  bool radioError = false;
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
      HomeWidgetBridge.update(title, subtitle, audio.playing);
    });
    audio.playerStateStream.listen((st) {
      notifyListeners();
      HomeWidgetBridge.update(title, subtitle, st.playing);
    });
    audio.loopModeStream.listen((_) => notifyListeners());
    _saveTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (audio.playing) _save();
    });

    final st = Settings.instance;
    final s = st.lastSession;
    if (s != null) {
      try {
        await _restore(s, autoplay: st.autoResume && !st.duaEnabled);
      } catch (_) {}
    }
    if (st.duaEnabled) {
      // If the background service just recited it (car started), don't repeat it.
      final last = await DuaBridge.lastPlayed();
      final recent = last != null && DateTime.now().difference(last).inMinutes < 3;
      if (recent) {
        if (s != null && st.autoResume) unawaited(_restore(s, autoplay: true));
      } else {
        unawaited(playDuaThenResume());
      }
    }
  }

  // ------------------------------------------------- interrupts (du'a, adhan)
  StreamSubscription<ProcessingState>? _intSub;

  Future<void> _playInterrupt(List<AudioSource> src, String title, String subtitle,
      {required Future<void> Function() then}) async {
    await _intSub?.cancel();
    final prevLoop = audio.loopMode;
    kind = PlayKind.special;
    this.title = title;
    this.subtitle = subtitle;
    artLetters = '';
    notifyListeners();
    await audio.setLoopMode(LoopMode.off);
    await audio.setAudioSource(ConcatenatingAudioSource(children: src));
    unawaited(audio.play());
    _intSub = audio.processingStateStream.listen((st) async {
      if (st == ProcessingState.completed) {
        await _intSub?.cancel();
        _intSub = null;
        await audio.setLoopMode(prevLoop);
        kind = PlayKind.none;
        await then();
        notifyListeners();
      }
    });
  }

  /// دعاء الركوب, then continue whatever was playing before.
  Future<void> playDuaThenResume() async {
    final lib = Library.instance;
    final urls = lib.duaUrls();
    final files = lib.duaFiles();
    final src = <AudioSource>[];
    if (files.isNotEmpty && files.length == urls.length) {
      for (var i = 0; i < files.length; i++) {
        src.add(AudioSource.file(files[i].path,
            tag: MediaItem(id: 'dua_$i', title: 'دعاء الركوب', artist: 'سبحان الذي سخر لنا هذا', album: 'دعاء')));
      }
    } else if (Settings.instance.allowStreaming) {
      for (var i = 0; i < urls.length; i++) {
        src.add(AudioSource.uri(Uri.parse(urls[i]),
            tag: MediaItem(id: 'dua_$i', title: 'دعاء الركوب', artist: 'سبحان الذي سخر لنا هذا', album: 'دعاء')));
      }
      unawaited(lib.downloadDua()); // keep it for next time
    }
    final snapshot = Settings.instance.lastSession;
    Future<void> resume() async {
      if (snapshot != null) await _restore(snapshot, autoplay: Settings.instance.autoResume);
    }

    if (src.isEmpty) return resume();
    try {
      await _playInterrupt(src, 'دعاء الركوب', 'سبحان الذي سخر لنا هذا', then: resume);
    } catch (_) {
      await resume();
    }
  }

  /// Called by the prayer service at adhan time.
  Future<void> adhanInterrupt(String prayerName, {bool silent = false}) async {
    if (kind == PlayKind.special) return;
    final wasPlaying = audio.playing;
    _save();
    final snapshot = Settings.instance.lastSession;
    final st = Settings.instance;
    Future<void> after() async {
      if (snapshot != null && kind != PlayKind.special) {
        await _restore(snapshot, autoplay: wasPlaying && st.resumeAfterAdhan);
      }
    }

    if (!st.adhanSound || silent) {
      if (wasPlaying) await audio.pause();
      if (wasPlaying && st.resumeAfterAdhan) {
        Future.delayed(const Duration(minutes: 4), () {
          if (!audio.playing) audio.play();
        });
      }
      return;
    }
    final lib = Library.instance;
    final f = lib.adhanFile();
    final url = lib.selectedAdhanUrl;
    AudioSource? src;
    final tag = MediaItem(id: 'adhan', title: 'أذان $prayerName', artist: 'حيّ على الصلاة', album: 'الأذان');
    if (f != null) {
      src = AudioSource.file(f.path, tag: tag);
    } else if (url != null && st.allowStreaming) {
      src = AudioSource.uri(Uri.parse(url), tag: tag);
      unawaited(lib.downloadAdhan());
    }
    if (src == null) {
      if (wasPlaying) await audio.pause();
      return;
    }
    try {
      await _playInterrupt([src], 'أذان $prayerName', 'حيّ على الصلاة', then: after);
    } catch (_) {}
  }

  /// Plays an adhan once (from settings), then puts the old session back paused.
  Future<void> previewAdhan(String url) async {
    final f = Library.instance.adhanFile(url);
    final src = f != null
        ? AudioSource.file(f.path, tag: const MediaItem(id: 'adhan_preview', title: 'تجربة الأذان'))
        : AudioSource.uri(Uri.parse(url), tag: const MediaItem(id: 'adhan_preview', title: 'تجربة الأذان'));
    _save();
    final snapshot = Settings.instance.lastSession;
    await _playInterrupt([src], 'تجربة الأذان', 'حيّ على الصلاة', then: () async {
      if (snapshot != null) await _restore(snapshot, autoplay: false);
    });
  }

  Future<void> stopInterrupt() async {
    if (kind != PlayKind.special) return;
    final cb = _intSub;
    _intSub = null;
    await cb?.cancel();
    await audio.stop();
    kind = PlayKind.none;
    final s = Settings.instance.lastSession;
    if (s != null) await _restore(s, autoplay: false);
    notifyListeners();
  }

  /// Titles around the current item (for carousel-style views).
  (String?, String?) get neighbours {
    final seq = audio.sequence;
    final i = audio.currentIndex;
    if (seq == null || i == null) return (null, null);
    String? t(int j) {
      if (j < 0 || j >= seq.length) return null;
      final tag = seq[j].tag;
      return tag is MediaItem ? tag.title : null;
    }

    return (t(i - 1), t(i + 1));
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
    azkarOwner = null;
    radioId = null;
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

  /// Live radio. Tries each mirror URL until one plays.
  Future<bool> playRadio(RadioStation st, {bool autoplay = true}) async {
    radioError = false;
    for (final u in st.urls) {
      try {
        kind = PlayKind.radio;
        radioId = st.id;
        reciterId = null;
        sheikhId = null;
        azkarOwner = null;
        artLetters = '';
        await audio.setAudioSource(
          AudioSource.uri(Uri.parse(u),
              tag: MediaItem(id: 'radio_${st.id}', title: st.name, artist: 'بث مباشر', album: 'الإذاعات')),
        );
        if (autoplay) unawaited(audio.play());
        notifyListeners();
        return true;
      } catch (_) {
        continue;
      }
    }
    radioError = true;
    notifyListeners();
    return false;
  }

  /// Morning / evening azkar of [ownerId] (a reciter id or ruqyah sheikh id).
  Future<bool> playAzkar(String ownerId, String ownerName, String when,
      {int index = 0, Duration position = Duration.zero, bool autoplay = true}) async {
    final lib = Library.instance;
    final stream = Settings.instance.allowStreaming;
    final remote = Sources.instance.azkarTracks(ownerId, when);
    final dir = lib.azkarDir(ownerId);
    final sources = <AudioSource>[];
    var start = 0;
    for (var i = 0; i < remote.length; i++) {
      final t = remote[i];
      final f = lib.localIn(dir, t);
      if (f == null && !stream) continue;
      if (i == index) start = sources.length;
      final tag = MediaItem(
        id: 'az_${ownerId}_${when}_$i',
        title: when == 'morning' ? 'أذكار الصباح' : 'أذكار المساء',
        artist: ownerName,
        album: 'الأذكار',
      );
      sources.add(f != null ? AudioSource.file(f.path, tag: tag) : AudioSource.uri(Uri.parse(t.url), tag: tag));
    }
    if (sources.isEmpty) return false;
    kind = PlayKind.azkar;
    azkarOwner = ownerId;
    azkarWhen = when;
    sheikhId = null;
    reciterId = null;
    artLetters = when == 'morning' ? '☀' : '☾';
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
    if (kind == PlayKind.radio) return;
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
    if (kind == PlayKind.none || kind == PlayKind.special) return;
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
      'azOwner': azkarOwner,
      'radio': radioId,
      'azWhen': azkarWhen,
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
      case 'radio':
        final id = s['radio'] as String?;
        final all = [...Sources.instance.radios, ...Sources.instance.radiosExtra];
        RadioStation? st;
        for (final r in all) {
          if (r.id == id) st = r;
        }
        if (st == null) return false;
        return playRadio(st, autoplay: autoplay);
      case 'azkar':
        final o = s['azOwner'] as String?;
        final w = s['azWhen'] as String?;
        if (o == null || w == null) return false;
        return playAzkar(o, (s['subtitle'] as String?) ?? '', w,
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
