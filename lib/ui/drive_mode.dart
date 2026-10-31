import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/library.dart';
import '../services/player.dart';
import 'glass.dart';

/// Full-screen, glance-friendly player for when the car is moving.
/// Drag left/right = next/previous (content follows the finger),
/// double-tap anywhere = play/pause.
class DriveMode extends StatefulWidget {
  const DriveMode({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        PageRouteBuilder(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 380),
          pageBuilder: (_, __, ___) => const DriveMode(),
          transitionsBuilder: (_, a, __, child) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
              scale: Tween(begin: 0.96, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
        ),
      );

  @override
  State<DriveMode> createState() => _DriveModeState();
}

class _DriveModeState extends State<DriveMode> with TickerProviderStateMixin {
  late Timer _clock;
  DateTime _now = DateTime.now();

  double _dx = 0; // live drag offset
  late final AnimationController _snap =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  Animation<double>? _snapAnim;

  int _dir = 1; // 1 = next (content leaves to the left), -1 = previous
  IconData? _hint;
  int _hintKey = 0;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
    _snap.addListener(() {
      if (_snapAnim != null) setState(() => _dx = _snapAnim!.value);
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    _snap.dispose();
    super.dispose();
  }

  void _flash(IconData icon) => setState(() {
        _hint = icon;
        _hintKey++;
      });

  void _animateTo(double target, {Curve curve = Curves.easeOutBack}) {
    _snapAnim = Tween(begin: _dx, end: target).animate(CurvedAnimation(parent: _snap, curve: curve));
    _snap.forward(from: 0);
  }

  Future<void> _onDragEnd(DragEndDetails d, double width) async {
    final p = Player.instance;
    final v = d.primaryVelocity ?? 0;
    final goNext = _dx < -width * 0.12 || v < -700;
    final goPrev = _dx > width * 0.12 || v > 700;
    if (goNext || goPrev) {
      _dir = goNext ? 1 : -1;
      _flash(goNext ? Icons.skip_next_rounded : Icons.skip_previous_rounded);
      goNext ? await p.next() : await p.previous();
    }
    _animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final p = Player.instance;
    final hh = (_now.hour % 12 == 0 ? 12 : _now.hour % 12).toString();
    final mm = _now.minute.toString().padLeft(2, '0');
    final ss = _now.second.toString().padLeft(2, '0');
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        final pull = (_dx / w).clamp(-1.0, 1.0).toDouble();
        return Stack(
          children: [
            const Positioned.fill(child: AppBackground()),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () {
                  final was = p.playing;
                  p.toggle();
                  _flash(was ? Icons.pause_rounded : Icons.play_arrow_rounded);
                },
                onHorizontalDragStart: (_) => _snap.stop(),
                onHorizontalDragUpdate: (d) => setState(() => _dx += d.delta.dx),
                onHorizontalDragEnd: (d) => _onDragEnd(d, w),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(26),
                    child: ListenableBuilder(
                      listenable: Listenable.merge([p, Library.instance]),
                      builder: (context, _) => Column(
                        children: [
                          // ------------------------------------------------ top bar
                          Row(
                            children: [
                              GlassButton(
                                icon: Icons.close_rounded,
                                label: 'خروج',
                                size: 72,
                                onTap: () => Navigator.of(context).pop(),
                              ),
                              const Spacer(),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text('$hh:$mm',
                                        style: TextStyle(
                                            fontSize: 54,
                                            fontWeight: FontWeight.w300,
                                            color: AppColors.text,
                                            fontFeatures: const [FontFeature.tabularFigures()])),
                                    const SizedBox(width: 6),
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 250),
                                      transitionBuilder: (child, a) => FadeTransition(
                                        opacity: a,
                                        child: SlideTransition(
                                          position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a),
                                          child: child,
                                        ),
                                      ),
                                      child: Text(ss,
                                          key: ValueKey(ss),
                                          style: TextStyle(
                                              fontSize: 30,
                                              color: AppColors.gold,
                                              fontFeatures: const [FontFeature.tabularFigures()])),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.directions_car_rounded, color: AppColors.gold, size: 40),
                              const SizedBox(width: 10),
                              Text('وضع السواقة',
                                  style: TextStyle(fontSize: 24, color: AppColors.gold, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const Spacer(),
                          // ------------------------------------------- now playing
                          Transform.translate(
                            offset: Offset(_dx * 0.55, 0),
                            child: Opacity(
                              opacity: (1 - pull.abs() * 0.9).clamp(0.15, 1.0).toDouble(),
                              child: Transform.rotate(
                                angle: pull * 0.04,
                                child: Row(
                                  children: [
                                    _PulsingArt(
                                      playing: p.playing,
                                      photoId: p.reciterId ?? p.sheikhId ?? p.azkarOwner,
                                    ),
                                    const SizedBox(width: 44),
                                    Expanded(
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 420),
                                        switchInCurve: Curves.easeOutCubic,
                                        switchOutCurve: Curves.easeInCubic,
                                        transitionBuilder: (child, a) => FadeTransition(
                                          opacity: a,
                                          child: SlideTransition(
                                            position: Tween(begin: Offset(0.25 * _dir, 0), end: Offset.zero)
                                                .animate(a),
                                            child: child,
                                          ),
                                        ),
                                        child: Column(
                                          key: ValueKey(p.title),
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.hasMedia ? p.title : 'اضغط تشغيل',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 66, fontWeight: FontWeight.w900, height: 1.2),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              p.hasMedia ? p.subtitle : 'هيكمّل من آخر مكان وقفت عنده',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 30, color: AppColors.gold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          const _LiveProgress(),
                          const Spacer(),
                          // ------------------------------------------------ controls
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GlassButton(
                                    icon: Icons.skip_previous_rounded,
                                    size: 128,
                                    onTap: () {
                                      _dir = -1;
                                      p.previous();
                                    }),
                                const SizedBox(width: 50),
                                StreamBuilder<PlayerState>(
                                  stream: p.audio.playerStateStream,
                                  builder: (context, snap) => AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                                    child: GlassButton(
                                      key: ValueKey(snap.data?.playing ?? false),
                                      icon: (snap.data?.playing ?? false)
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 186,
                                      primary: true,
                                      onTap: p.toggle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 50),
                                GlassButton(
                                    icon: Icons.skip_next_rounded,
                                    size: 128,
                                    onTap: () {
                                      _dir = 1;
                                      p.next();
                                    }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('اسحب يمين أو شمال للتنقل · دوس مرتين في أي حتة للإيقاف',
                              style: TextStyle(color: AppColors.muted, fontSize: 18)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // ---------------------------------------- gesture feedback (animated)
            if (_hint != null)
              IgnorePointer(
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_hintKey),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 750),
                    curve: Curves.easeOut,
                    onEnd: () {
                      if (mounted) setState(() => _hint = null);
                    },
                    builder: (context, t, _) {
                      final appear = (t * 3).clamp(0.0, 1.0).toDouble();
                      final fade = t < 0.6 ? 1.0 : (1 - (t - 0.6) / 0.4);
                      return Opacity(
                        opacity: (appear * fade).clamp(0.0, 1.0).toDouble(),
                        child: Transform.scale(
                          scale: 0.7 + 0.4 * Curves.easeOutBack.transform(appear),
                          child: Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.bg0.withOpacity(0.55),
                              border: Border.all(color: AppColors.gold.withOpacity(0.7), width: 2),
                              boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.35), blurRadius: 50)],
                            ),
                            child: Icon(_hint, size: 100, color: AppColors.gold),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

/// Mushaf art with a slow breathing halo while audio plays.
class _PulsingArt extends StatefulWidget {
  final bool playing;
  final String? photoId;
  const _PulsingArt({required this.playing, this.photoId});

  @override
  State<_PulsingArt> createState() => _PulsingArtState();
}

class _PulsingArtState extends State<_PulsingArt> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    if (widget.playing) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _PulsingArt old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_c.isAnimating) _c.repeat();
    if (!widget.playing && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 250,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Stack(
          alignment: Alignment.center,
          children: [
            for (final phase in [0.0, 0.5])
              Builder(builder: (_) {
                final t = (_c.value + phase) % 1.0;
                return Opacity(
                  opacity: widget.playing ? (1 - t) * 0.5 : 0,
                  child: Container(
                    width: 210 + 40 * t,
                    height: 210 + 40 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 2),
                    ),
                  ),
                );
              }),
            child!,
          ],
        ),
        child: ReciterAvatar('', photoId: widget.photoId, size: 210, glow: widget.playing),
      ),
    );
  }
}

/// Animated waveform progress: bars dance while playing, the played part
/// glows in the theme gradient. Tap / drag on it to seek.
class _LiveProgress extends StatefulWidget {
  const _LiveProgress();

  @override
  State<_LiveProgress> createState() => _LiveProgressState();
}

class _LiveProgressState extends State<_LiveProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _wave =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  void _seek(double dx, double width) {
    final audio = Player.instance.audio;
    final d = audio.duration;
    if (d == null || width <= 0) return;
    final f = (dx / width).clamp(0.0, 1.0);
    audio.seek(Duration(milliseconds: (d.inMilliseconds * f).round()));
  }

  @override
  Widget build(BuildContext context) {
    final audio = Player.instance.audio;
    return StreamBuilder<Duration>(
      stream: audio.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = audio.duration ?? Duration.zero;
        final f = dur.inMilliseconds <= 0 ? 0.0 : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0).toDouble();
        final remain = dur - pos;
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, c) => GestureDetector(
                  onTapDown: (d) => _seek(d.localPosition.dx, c.maxWidth),
                  onHorizontalDragUpdate: (d) => _seek(d.localPosition.dx, c.maxWidth),
                  child: AnimatedBuilder(
                    animation: _wave,
                    builder: (context, _) => CustomPaint(
                      size: Size(c.maxWidth, 90),
                      painter: _WavePainter(
                        progress: f,
                        t: _wave.value,
                        playing: audio.playing,
                        a: AppColors.gold,
                        b: AppColors.emerald,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(fmtDuration(pos),
                      style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                  const Spacer(),
                  Text('-${fmtDuration(remain.isNegative ? Duration.zero : remain)}',
                      style: TextStyle(
                          fontSize: 26,
                          color: AppColors.muted,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final double t;
  final bool playing;
  final Color a;
  final Color b;
  _WavePainter({required this.progress, required this.t, required this.playing, required this.a, required this.b});

  static final List<double> _seed = List.generate(72, (i) {
    final r = math.Random(i * 7919);
    return 0.35 + r.nextDouble() * 0.65;
  });

  @override
  void paint(Canvas canvas, Size size) {
    const n = 72;
    final gap = size.width / n;
    final barW = gap * 0.55;
    final mid = size.height / 2;
    final played = Paint()
      ..shader = LinearGradient(colors: [b, a]).createShader(Offset.zero & size);
    final rest = Paint()..color = Colors.white.withOpacity(0.18);
    final glow = Paint()
      ..color = a.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    for (var i = 0; i < n; i++) {
      final x = i * gap + gap / 2;
      final phase = 2 * math.pi * (t + i / 18);
      final dance = playing ? 0.55 + 0.45 * math.sin(phase).abs() : 0.35;
      final hgt = (size.height * 0.92) * _seed[i] * dance;
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, mid), width: barW, height: math.max(6, hgt)),
        Radius.circular(barW),
      );
      final isPlayed = (i + 0.5) / n <= progress;
      if (isPlayed) canvas.drawRRect(r, glow);
      canvas.drawRRect(r, isPlayed ? played : rest);
    }
    // playhead
    final px = progress * size.width;
    canvas.drawLine(Offset(px, 4), Offset(px, size.height - 4),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.progress != progress || old.t != t || old.playing != playing || old.a != a;
}
