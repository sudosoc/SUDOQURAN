import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/library.dart';
import '../services/player.dart';
import '../services/prayer.dart';
import '../services/settings.dart';
import 'adhan_banner.dart';
import 'car_dash.dart';
import 'glass.dart';
import 'interrupt_bar.dart';

/// The driving-mode looks the user can pick from (Settings → وضع السواقة).
class DriveStyle {
  final String id;
  final String name;
  final String desc;
  final IconData icon;
  const DriveStyle(this.id, this.name, this.desc, this.icon);
}

const driveStyles = <DriveStyle>[
  DriveStyle('car', 'عداد السرعة', 'عداد GPS حقيقي بـ 10 أشكال متحركة + كمبيوتر رحلة — كله بيتخصص', Icons.directions_car_filled_rounded),
  DriveStyle('luxury', 'فخامة', 'أسود صافي، اسم السورة ضخم وحلقة تقدّم ذهبية', Icons.diamond_outlined),
  DriveStyle('cockpit', 'تابلوه', 'عدادات زي عدادات العربية', Icons.speed_rounded),
  DriveStyle('ambient', 'أجواء', 'ألوان بتتحرك بهدوء ورا الكلام', Icons.blur_on_rounded),
  DriveStyle('vinyl', 'أسطوانة', 'المصحف بيلف زي الأسطوانة وهو بيقرأ', Icons.album_rounded),
  DriveStyle('carousel', 'شريط السور', 'السورة اللي فاتت والجاية جنب الحالية', Icons.view_carousel_rounded),
  DriveStyle('classic', 'كلاسيك', 'الموجة الحية وصورة المصحف', Icons.graphic_eq_rounded),
  DriveStyle('focus', 'ليلي', 'أقل حاجة ممكنة — مريح للعين بالليل', Icons.nightlight_round),
];

/// Full-screen, glance-friendly player for when the car is moving.
/// Drag left/right = next/previous, double-tap anywhere = play/pause.
class DriveMode extends StatefulWidget {
  final String? previewStyle;
  const DriveMode({super.key, this.previewStyle});

  static Future<void> open(BuildContext context, {String? style}) => Navigator.of(context).push(
        PageRouteBuilder(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 380),
          pageBuilder: (_, __, ___) => DriveMode(previewStyle: style),
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

  double _dx = 0;
  late final AnimationController _snap =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  Animation<double>? _snapAnim;
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();

  int _dir = 1;
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
    _loop.dispose();
    super.dispose();
  }

  void _flash(IconData icon) => setState(() {
        _hint = icon;
        _hintKey++;
      });

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
    _snapAnim = Tween(begin: _dx, end: 0.0).animate(CurvedAnimation(parent: _snap, curve: Curves.easeOutBack));
    _snap.forward(from: 0);
  }

  void _next() {
    _dir = 1;
    Player.instance.next();
  }

  void _prev() {
    _dir = -1;
    Player.instance.previous();
  }

  @override
  Widget build(BuildContext context) {
    final p = Player.instance;
    final st = Settings.instance;
    final style = widget.previewStyle ?? st.driveStyle;
    final clock = fmtClock(_now, h24: st.clock24, seconds: true);
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        final pull = (_dx / w).clamp(-1.0, 1.0).toDouble();
        return Stack(
          children: [
            Positioned.fill(child: _Backdrop(style: style, loop: _loop)),
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
                      listenable: Listenable.merge([p, Library.instance, Prayer.instance]),
                      builder: (context, _) {
                        final s = _DriveData(
                          p: p,
                          clock: clock,
                          dir: _dir,
                          pull: pull,
                          dx: _dx,
                          loop: _loop,
                          next: _next,
                          prev: _prev,
                        );
                        return Column(
                          children: [
                            _TopBar(clock: clock, style: style),
                            Expanded(child: _body(style, s)),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            if (_hint != null) _HintBubble(key: ValueKey(_hintKey), icon: _hint!, onEnd: () {
              if (mounted) setState(() => _hint = null);
            }),
            const AdhanBanner(),
            const InterruptBar(),
          ],
        );
      }),
    );
  }

  Widget _body(String style, _DriveData s) {
    switch (style) {
      case 'car':
        return CarDashBody(swap: s.swap, next: s.next, prev: s.prev);
      case 'cockpit':
        return _CockpitBody(s);
      case 'ambient':
        return _AmbientBody(s);
      case 'vinyl':
        return _VinylBody(s);
      case 'carousel':
        return _CarouselBody(s);
      case 'classic':
        return _ClassicBody(s);
      case 'focus':
        return _FocusBody(s);
      default:
        return _LuxuryBody(s);
    }
  }
}

class _DriveData {
  final Player p;
  final String clock;
  final int dir;
  final double pull;
  final double dx;
  final AnimationController loop;
  final VoidCallback next;
  final VoidCallback prev;
  _DriveData({
    required this.p,
    required this.clock,
    required this.dir,
    required this.pull,
    required this.dx,
    required this.loop,
    required this.next,
    required this.prev,
  });

  String get title => p.hasMedia ? p.title : 'اضغط تشغيل';
  String get subtitle => p.hasMedia ? p.subtitle : 'هيكمّل من آخر مكان وقفت عنده';
  String? get photoId => p.reciterId ?? p.sheikhId ?? p.azkarOwner;

  /// Content follows the finger while dragging.
  Widget drag(Widget child) => Transform.translate(
        offset: Offset(dx * 0.55, 0),
        child: Opacity(
          opacity: (1 - pull.abs() * 0.9).clamp(0.15, 1.0).toDouble(),
          child: Transform.rotate(angle: pull * 0.03, child: child),
        ),
      );

  /// Title swaps slide in from the swipe direction.
  Widget swap(Widget child) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (c, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: Offset(0.25 * dir, 0), end: Offset.zero).animate(a),
            child: c,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(p.title), child: child),
      );
}

// ------------------------------------------------------------------ chrome
class _TopBar extends StatelessWidget {
  final String clock;
  final String style;
  const _TopBar({required this.clock, required this.style});

  @override
  Widget build(BuildContext context) {
    final next = Prayer.instance.next;
    final left = next.$2.difference(DateTime.now());
    return Row(
      children: [
        GlassButton(icon: Icons.close_rounded, label: 'خروج', size: 68, onTap: () => Navigator.of(context).pop()),
        const Spacer(),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(clock,
              style: TextStyle(
                  fontSize: style == 'focus' ? 40 : 50,
                  fontWeight: FontWeight.w300,
                  color: style == 'focus' ? AppColors.muted : AppColors.text,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ),
        const Spacer(),
        if (Settings.instance.prayerEnabled)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.gold.withOpacity(0.4)),
            ),
            child: Row(children: [
              Icon(Icons.mosque_rounded, color: AppColors.gold, size: 26),
              const SizedBox(width: 8),
              Text('${next.$1} بعد ${fmtCountdown(left)}',
                  style: TextStyle(fontSize: 20, color: AppColors.gold)),
            ]),
          ),
      ],
    );
  }
}

class _HintBubble extends StatelessWidget {
  final IconData icon;
  final VoidCallback onEnd;
  const _HintBubble({super.key, required this.icon, required this.onEnd});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 750),
          curve: Curves.easeOut,
          onEnd: onEnd,
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
                    color: AppColors.bg0.withOpacity(0.6),
                    border: Border.all(color: AppColors.gold.withOpacity(0.7), width: 2),
                    boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.35), blurRadius: 50)],
                  ),
                  child: Icon(icon, size: 100, color: AppColors.gold),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Backgrounds per style.
class _Backdrop extends StatelessWidget {
  final String style;
  final AnimationController loop;
  const _Backdrop({required this.style, required this.loop});

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case 'luxury':
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, 0.15),
              radius: 1.1,
              colors: [AppColors.gold.withOpacity(0.10), Colors.black],
            ),
          ),
        );
      case 'focus':
        return const ColoredBox(color: Colors.black);
      case 'ambient':
        return RepaintBoundary(
          child: AnimatedBuilder(
            animation: loop,
            builder: (context, _) => CustomPaint(painter: _AuroraPainter(loop.value)),
          ),
        );
      default:
        return const AppBackground();
    }
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  _AuroraPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.bg0);
    final colors = [AppColors.emerald, AppColors.gold, AppColors.teal, AppColors.bg1];
    for (var i = 0; i < 4; i++) {
      final a = 2 * math.pi * (t + i / 4);
      final c = Offset(
        size.width * (0.5 + 0.35 * math.cos(a * (i.isEven ? 1 : -1))),
        size.height * (0.5 + 0.30 * math.sin(a * 1.3)),
      );
      final r = size.height * (0.55 + 0.1 * math.sin(a * 2));
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [colors[i].withOpacity(0.45), colors[i].withOpacity(0)])
              .createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) => old.t != t;
}

// ------------------------------------------------------------- shared bits
class _PlayButton extends StatelessWidget {
  final double size;
  final bool ghost;
  const _PlayButton({this.size = 180, this.ghost = false});

  @override
  Widget build(BuildContext context) {
    final p = Player.instance;
    return StreamBuilder<PlayerState>(
      stream: p.audio.playerStateStream,
      builder: (context, snap) {
        final playing = snap.data?.playing ?? false;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: GlassButton(
            key: ValueKey(playing),
            icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: size,
            primary: !ghost,
            onTap: p.toggle,
          ),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  final _DriveData s;
  final double side;
  final double main;
  final bool ghost;
  const _Controls(this.s, {this.side = 124, this.main = 180, this.ghost = false});

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GlassButton(icon: Icons.skip_previous_rounded, size: side, onTap: s.prev),
            SizedBox(width: side * 0.4),
            _PlayButton(size: main, ghost: ghost),
            SizedBox(width: side * 0.4),
            GlassButton(icon: Icons.skip_next_rounded, size: side, onTap: s.next),
          ],
        ),
      );
}

/// Position stream helper → (fraction, position, duration).
class _Pos extends StatelessWidget {
  final Widget Function(BuildContext, double, Duration, Duration) builder;
  const _Pos({required this.builder});

  @override
  Widget build(BuildContext context) {
    final audio = Player.instance.audio;
    return StreamBuilder<Duration>(
      stream: audio.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = audio.duration ?? Duration.zero;
        final f = dur.inMilliseconds <= 0
            ? 0.0
            : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0).toDouble();
        return builder(context, f, pos, dur);
      },
    );
  }
}

TextStyle _tab(double size, Color c, [FontWeight w = FontWeight.w600]) =>
    TextStyle(fontSize: size, color: c, fontWeight: w, fontFeatures: const [FontFeature.tabularFigures()]);

// ================================================================= styles
/// D1 — black, giant title, gold progress ring around play.
class _LuxuryBody extends StatelessWidget {
  final _DriveData s;
  const _LuxuryBody(this.s);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        s.drag(s.swap(Column(children: [
          Text(s.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 92,
                fontWeight: FontWeight.w900,
                height: 1.1,
                foreground: Paint()
                  ..shader = LinearGradient(colors: [AppColors.text, AppColors.gold])
                      .createShader(const Rect.fromLTWH(0, 0, 900, 100)),
              )),
          const SizedBox(height: 6),
          Text(s.subtitle, style: TextStyle(fontSize: 28, color: AppColors.gold.withOpacity(0.85), letterSpacing: 1)),
        ]))),
        const SizedBox(height: 26),
        _Pos(builder: (context, f, pos, dur) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 150, child: Text(fmtDuration(pos), textAlign: TextAlign.right, style: _tab(30, AppColors.gold))),
                const SizedBox(width: 30),
                GlassButton(icon: Icons.skip_previous_rounded, size: 100, onTap: s.prev),
                const SizedBox(width: 30),
                SizedBox(
                  width: 250,
                  height: 250,
                  child: Stack(alignment: Alignment.center, children: [
                    CustomPaint(size: const Size(250, 250), painter: _RingPainter(f, AppColors.gold, AppColors.emerald)),
                    const _PlayButton(size: 170),
                  ]),
                ),
                const SizedBox(width: 30),
                GlassButton(icon: Icons.skip_next_rounded, size: 100, onTap: s.next),
                const SizedBox(width: 30),
                SizedBox(width: 150, child: Text('-${fmtDuration(dur - pos)}', style: _tab(24, AppColors.muted))),
              ],
            ),
          );
        }),
        const Spacer(),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double f;
  final Color a;
  final Color b;
  _RingPainter(this.f, this.a, this.b);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - 8);
    canvas.drawArc(rect, 0, 2 * math.pi, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = Colors.white.withOpacity(0.1));
    final sweep = 2 * math.pi * f;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi,
        colors: [b, a, b],
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.max(0.001, sweep), false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22
          ..color = a.withOpacity(0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawArc(rect, -math.pi / 2, math.max(0.001, sweep), false, paint);
    final end = Offset(rect.center.dx + rect.width / 2 * math.cos(-math.pi / 2 + sweep),
        rect.center.dy + rect.height / 2 * math.sin(-math.pi / 2 + sweep));
    canvas.drawCircle(end, 9, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.f != f || old.a != a;
}

/// D2 — two car-style gauges.
class _CockpitBody extends StatelessWidget {
  final _DriveData s;
  const _CockpitBody(this.s);

  @override
  Widget build(BuildContext context) {
    final p = s.p;
    final idx = p.audio.currentIndex ?? 0;
    final total = p.audio.sequence?.length ?? 1;
    return Column(
      children: [
        const Spacer(),
        _Pos(builder: (context, f, pos, dur) {
          return Row(
            children: [
              _Gauge(value: f, big: fmtDuration(pos), small: 'الوقت', a: AppColors.gold, b: AppColors.emerald),
              const SizedBox(width: 30),
              Expanded(
                child: s.drag(s.swap(Column(children: [
                  Text(s.title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w900)),
                  Text(s.subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 26, color: AppColors.gold)),
                ]))),
              ),
              const SizedBox(width: 30),
              _Gauge(
                value: total <= 1 ? 1 : (idx + 1) / total,
                big: '${idx + 1}',
                small: 'من $total',
                a: AppColors.emerald,
                b: AppColors.teal,
              ),
            ],
          );
        }),
        const SizedBox(height: 30),
        _Controls(s, side: 110, main: 160),
        const Spacer(),
      ],
    );
  }
}

class _Gauge extends StatelessWidget {
  final double value;
  final String big;
  final String small;
  final Color a;
  final Color b;
  const _Gauge({required this.value, required this.big, required this.small, required this.a, required this.b});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(alignment: Alignment.center, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) =>
              CustomPaint(size: const Size(280, 280), painter: _GaugePainter(v, a, b)),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Directionality(textDirection: TextDirection.ltr, child: Text(big, style: _tab(46, AppColors.text, FontWeight.w800))),
          Text(small, style: TextStyle(fontSize: 18, color: AppColors.muted)),
        ]),
      ]),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double v;
  final Color a;
  final Color b;
  _GaugePainter(this.v, this.a, this.b);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 14;
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;
    // ticks
    for (var i = 0; i <= 30; i++) {
      final ang = start + sweep * i / 30;
      final long = i % 5 == 0;
      final p1 = c + Offset(math.cos(ang), math.sin(ang)) * (r - (long ? 22 : 12));
      final p2 = c + Offset(math.cos(ang), math.sin(ang)) * (r - 4);
      final lit = i / 30 <= v;
      canvas.drawLine(p1, p2,
          Paint()
            ..color = lit ? Color.lerp(b, a, i / 30)! : Colors.white24
            ..strokeWidth = long ? 4 : 2
            ..strokeCap = StrokeCap.round);
    }
    final rect = Rect.fromCircle(center: c, radius: r + 6);
    canvas.drawArc(rect, start, sweep * v, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(colors: [b, a], startAngle: start, endAngle: start + sweep).createShader(rect));
    // needle
    final na = start + sweep * v;
    canvas.drawLine(c, c + Offset(math.cos(na), math.sin(na)) * (r - 34),
        Paint()
          ..color = a
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(c, 8, Paint()..color = a);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.v != v || old.a != a;
}

/// D3 — moving aurora, big airy type, ghost buttons.
class _AmbientBody extends StatelessWidget {
  final _DriveData s;
  const _AmbientBody(this.s);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        s.drag(s.swap(Column(children: [
          Text(s.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 84, fontWeight: FontWeight.w300, letterSpacing: 2)),
          Text(s.subtitle, style: TextStyle(fontSize: 28, color: AppColors.text.withOpacity(0.75))),
        ]))),
        const SizedBox(height: 34),
        _Pos(builder: (context, f, pos, dur) => Directionality(
              textDirection: TextDirection.ltr,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 120),
                child: Column(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: f,
                      minHeight: 8,
                      color: Colors.white.withOpacity(0.9),
                      backgroundColor: Colors.white.withOpacity(0.15),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Text(fmtDuration(pos), style: _tab(24, Colors.white70)),
                    const Spacer(),
                    Text(fmtDuration(dur), style: _tab(24, Colors.white54)),
                  ]),
                ]),
              ),
            )),
        const SizedBox(height: 26),
        _Controls(s, side: 110, main: 160, ghost: true),
        const Spacer(),
      ],
    );
  }
}

/// Spinning record with the mushaf in the middle.
class _VinylBody extends StatelessWidget {
  final _DriveData s;
  const _VinylBody(this.s);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedBuilder(
          animation: s.loop,
          builder: (context, child) => Transform.rotate(
            angle: s.p.playing ? s.loop.value * 2 * math.pi * 4 : 0,
            child: child,
          ),
          child: SizedBox(
            width: 460,
            height: 460,
            child: Stack(alignment: Alignment.center, children: [
              const CustomPaint(size: Size(460, 460), painter: _RecordPainter()),
              ClipOval(child: Image.asset('assets/mushaf.jpg', width: 200, height: 200, fit: BoxFit.cover)),
              Container(width: 18, height: 18, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle)),
            ]),
          ),
        ),
        const SizedBox(width: 40),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              s.drag(s.swap(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900)),
                Text(s.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 28, color: AppColors.gold)),
              ]))),
              const SizedBox(height: 24),
              const _LiveProgress(),
              const SizedBox(height: 20),
              _Controls(s, side: 104, main: 150),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecordPainter extends CustomPainter {
  const _RecordPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0A0A0A));
    for (var i = 0; i < 40; i++) {
      canvas.drawCircle(c, r - 8 - i * 3.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.white.withOpacity(i.isEven ? 0.05 : 0.02));
    }
    canvas.drawArc(Rect.fromCircle(center: c, radius: r - 30), -2.4, 0.9, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 60
          ..color = Colors.white.withOpacity(0.04));
    canvas.drawCircle(c, 108, Paint()..color = AppColors.gold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Previous · current · next as a sliding strip.
class _CarouselBody extends StatelessWidget {
  final _DriveData s;
  const _CarouselBody(this.s);

  @override
  Widget build(BuildContext context) {
    final (prev, next) = s.p.neighbours;
    Widget side(String? t, VoidCallback onTap) => Expanded(
          flex: 2,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: t == null ? 0 : 0.55,
            child: GestureDetector(
              onTap: t == null ? null : onTap,
              child: Glass(
                blur: false,
                radius: 30,
                padding: const EdgeInsets.symmetric(vertical: 46, horizontal: 16),
                child: Text(t ?? '',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        );
    return Column(
      children: [
        const Spacer(),
        s.drag(Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              side(prev, s.prev),
              const SizedBox(width: 20),
              Expanded(
                flex: 4,
                child: Glass(
                  radius: 36,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                  borderColor: AppColors.gold,
                  borderWidth: 2,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: s.swap(Column(children: [
                      ReciterAvatar('', photoId: s.photoId, size: 110, glow: s.p.playing),
                      const SizedBox(height: 16),
                      Text(s.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900)),
                      Text(s.subtitle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 24, color: AppColors.gold)),
                    ])),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              side(next, s.next),
            ],
          ),
        )),
        const SizedBox(height: 26),
        _Pos(builder: (context, f, pos, dur) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 200),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: LinearProgressIndicator(
                  value: f,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.gold,
                  backgroundColor: Colors.white12,
                ),
              ),
            )),
        const SizedBox(height: 22),
        _Controls(s, side: 100, main: 150),
        const Spacer(),
      ],
    );
  }
}

/// The original live-waveform layout.
class _ClassicBody extends StatelessWidget {
  final _DriveData s;
  const _ClassicBody(this.s);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        s.drag(Row(children: [
          _PulsingArt(playing: s.p.playing, photoId: s.photoId),
          const SizedBox(width: 44),
          Expanded(
            child: s.swap(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 66, fontWeight: FontWeight.w900, height: 1.2)),
              const SizedBox(height: 6),
              Text(s.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 30, color: AppColors.gold)),
            ])),
          ),
        ])),
        const SizedBox(height: 30),
        const _LiveProgress(),
        const Spacer(),
        _Controls(s),
        const SizedBox(height: 10),
      ],
    );
  }
}

/// Night: only the essentials, low brightness.
class _FocusBody extends StatelessWidget {
  final _DriveData s;
  const _FocusBody(this.s);

  @override
  Widget build(BuildContext context) {
    final dim = AppColors.gold.withOpacity(0.7);
    return Column(
      children: [
        const Spacer(),
        s.drag(s.swap(Text(s.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 110, fontWeight: FontWeight.w800, color: dim)))),
        Text(s.subtitle, style: TextStyle(fontSize: 26, color: Colors.white38)),
        const SizedBox(height: 40),
        _Pos(builder: (context, f, pos, dur) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 260),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: LinearProgressIndicator(
                  value: f,
                  minHeight: 3,
                  color: dim,
                  backgroundColor: Colors.white10,
                ),
              ),
            )),
        const Spacer(),
        Opacity(opacity: 0.45, child: _Controls(s, side: 96, main: 130, ghost: true)),
        const SizedBox(height: 10),
        Text('دوس مرتين للإيقاف · اسحب للتنقل', style: TextStyle(color: Colors.white24, fontSize: 18)),
      ],
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
