import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/gps.dart';
import '../services/player.dart';
import '../services/prayer.dart';
import '../services/settings.dart';
import 'glass.dart';

/// Option catalogues for the customisable speedometer style.
const carGauges = <(String, String)>[
  ('analog', 'كلاسيك بإبرة'),
  ('digital', 'رقمي'),
  ('neon', 'نيون'),
  ('sport', 'سبور'),
  ('minimal', 'رقم بس'),
];
const carModels = <(String, String)>[
  ('sedan', 'سيدان (زي الكورولا)'),
  ('suv', 'SUV'),
  ('hatch', 'هاتشباك'),
  ('sport', 'رياضية'),
  ('pickup', 'بيك أب'),
  ('none', 'من غير عربية'),
];
const carColors = <(int, String)>[
  (0xFFEDEDED, 'أبيض لؤلؤي'),
  (0xFFB9BDC4, 'فضي'),
  (0xFF5B6068, 'رمادي'),
  (0xFF151515, 'أسود'),
  (0xFFB0141C, 'أحمر'),
  (0xFF1C3F8C, 'أزرق'),
  (0xFF7A5230, 'بني'),
  (0xFF2E5E3E, 'أخضر'),
];
const carTilesAll = <(String, String, IconData)>[
  ('trip', 'مسافة المشوار', Icons.route_rounded),
  ('time', 'وقت المشوار', Icons.timer_outlined),
  ('max', 'أقصى سرعة', Icons.trending_up_rounded),
  ('avg', 'متوسط السرعة', Icons.speed_rounded),
  ('heading', 'الاتجاه', Icons.explore_rounded),
  ('alt', 'الارتفاع', Icons.terrain_rounded),
  ('clock', 'الساعة', Icons.schedule_rounded),
  ('z100', '0 ← 100', Icons.bolt_rounded),
  ('gps', 'الأقمار', Icons.satellite_alt_rounded),
  ('prayer', 'الصلاة الجاية', Icons.mosque_rounded),
  ('hijri', 'التاريخ الهجري', Icons.calendar_month_rounded),
];

/// "عداد السرعة" drive style: live GPS speed, your car, trip computer, Quran player.
class CarDashBody extends StatefulWidget {
  final Widget Function(Widget) swap;
  final VoidCallback next;
  final VoidCallback prev;
  const CarDashBody({super.key, required this.swap, required this.next, required this.prev});

  @override
  State<CarDashBody> createState() => _CarDashBodyState();
}

class _CarDashBodyState extends State<CarDashBody> with SingleTickerProviderStateMixin {
  late final AnimationController _road = AnimationController(vsync: this, duration: const Duration(seconds: 1))
    ..repeat();
  double _roadPos = 0;
  double _wheel = 0;
  DateTime _last = DateTime.now();

  @override
  void initState() {
    super.initState();
    Gps.instance.start();
    _road.addListener(() {
      final now = DateTime.now();
      final dt = now.difference(_last).inMicroseconds / 1e6;
      _last = now;
      final v = Gps.instance.speedKmh / 3.6; // m/s
      _roadPos = (_roadPos + v * dt * 18) % 1000;
      _wheel = (_wheel + v * dt / 0.31) % (2 * math.pi);
    });
  }

  @override
  void dispose() {
    _road.dispose();
    Gps.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = Settings.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([Gps.instance, st]),
      builder: (context, _) {
        final g = Gps.instance;
        final mph = st.carMph;
        final f = mph ? 0.621371 : 1.0;
        final speed = g.speedKmh * f;
        final max = st.carMax * (mph ? 0.65 : 1.0);
        final limit = st.carLimit * f;
        final warn = limit > 0 && speed > limit;
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  // --------------------------------------------------- gauge
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _Speedometer(
                          style: st.carGauge,
                          speed: speed,
                          max: max,
                          unit: mph ? 'mph' : 'كم/س',
                          warn: warn,
                          error: g.error ?? (g.hasFix ? null : 'بيدوّر على GPS…'),
                          onRetry: () {
                            Gps.instance.stop();
                            Gps.instance.start();
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // -------------------------------------------- car + tiles
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        if (st.carModel != 'none')
                          SizedBox(
                            height: 210,
                            child: AnimatedBuilder(
                              animation: _road,
                              builder: (context, _) => CustomPaint(
                                size: Size.infinite,
                                painter: _CarScenePainter(
                                  model: st.carModel,
                                  color: Color(st.carColor),
                                  road: st.carRoad,
                                  roadPos: _roadPos,
                                  wheel: _wheel,
                                  lights: DateTime.now().hour >= 18 || DateTime.now().hour < 6,
                                  accent: AppColors.gold,
                                  brake: g.rawKmh + 3 < g.speedKmh,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                        Expanded(child: _Tiles(warn: warn, mph: mph)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _MiniPlayer(swap: widget.swap, next: widget.next, prev: widget.prev),
          ],
        );
      },
    );
  }
}

// ================================================================ gauge
class _Speedometer extends StatelessWidget {
  final String style;
  final double speed;
  final double max;
  final String unit;
  final bool warn;
  final String? error;
  final VoidCallback onRetry;
  const _Speedometer({
    required this.style,
    required this.speed,
    required this.max,
    required this.unit,
    required this.warn,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final accent = warn ? const Color(0xFFFF3B3B) : AppColors.gold;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: speed),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final frac = (v / max).clamp(0.0, 1.0).toDouble();
        final numberSize = switch (style) {
          'minimal' => 190.0,
          'digital' => 150.0,
          _ => 110.0,
        };
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _GaugePainter(style: style, f: frac, max: max, accent: accent, b: AppColors.emerald, warn: warn),
              ),
            ),
            Align(
              alignment: style == 'analog' || style == 'sport' ? const Alignment(0, 0.42) : Alignment.center,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    v.round().toString(),
                    style: TextStyle(
                      fontSize: style == 'analog' || style == 'sport' ? 72 : numberSize,
                      fontWeight: style == 'minimal' ? FontWeight.w200 : FontWeight.w800,
                      height: 1,
                      color: warn ? accent : AppColors.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      shadows: style == 'neon' ? [Shadow(color: accent, blurRadius: 30)] : null,
                    ),
                  ),
                ),
                Text(unit, style: TextStyle(fontSize: 22, color: accent, letterSpacing: 2)),
                if (warn) Text('تخطيت الحد', style: TextStyle(fontSize: 18, color: accent, fontWeight: FontWeight.w800)),
              ]),
            ),
            if (error != null)
              Align(
                alignment: const Alignment(0, 0.92),
                child: GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.black54,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.gps_not_fixed_rounded, color: AppColors.gold, size: 20),
                      const SizedBox(width: 8),
                      Text(error!, style: const TextStyle(fontSize: 16)),
                    ]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final String style;
  final double f;
  final double max;
  final Color accent;
  final Color b;
  final bool warn;
  _GaugePainter({required this.style, required this.f, required this.max, required this.accent, required this.b, required this.warn});

  static const start = math.pi * 0.75;
  static const sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 6;
    switch (style) {
      case 'digital':
        _digital(canvas, c, r);
      case 'neon':
        _neon(canvas, c, r);
      case 'sport':
        _analog(canvas, c, r, sport: true);
      case 'minimal':
        _minimal(canvas, c, r);
      default:
        _analog(canvas, c, r);
    }
  }

  Offset _p(Offset c, double r, double a) => c + Offset(math.cos(a), math.sin(a)) * r;

  void _label(Canvas canvas, String t, Offset at, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontSize: size, color: color, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  void _analog(Canvas canvas, Offset c, double r, {bool sport = false}) {
    // bezel
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = SweepGradient(colors: sport
                  ? const [Color(0xFF3A0A0A), Color(0xFF8A1A1A), Color(0xFF3A0A0A), Color(0xFF8A1A1A), Color(0xFF3A0A0A)]
                  : const [Color(0xFF6E7378), Color(0xFFE6E8EB), Color(0xFF6E7378), Color(0xFFE6E8EB), Color(0xFF6E7378)])
              .createShader(Rect.fromCircle(center: c, radius: r)));
    // face
    canvas.drawCircle(
        c,
        r * 0.94,
        Paint()
          ..shader = RadialGradient(colors: sport
                  ? const [Color(0xFF1A1A1A), Color(0xFF050505)]
                  : [const Color(0xFF15191F), Colors.black])
              .createShader(Rect.fromCircle(center: c, radius: r)));
    if (sport) {
      // carbon weave hint
      final p = Paint()..color = Colors.white.withOpacity(0.025);
      for (var i = -r; i < r; i += 8) {
        canvas.drawLine(c + Offset(i, -r), c + Offset(i + r, r), p..strokeWidth = 3);
      }
    }
    // red zone
    final rz = Rect.fromCircle(center: c, radius: r * 0.86);
    canvas.drawArc(rz, start + sweep * 0.82, sweep * 0.18, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.05
          ..color = const Color(0xFFD62828));
    // progress arc
    canvas.drawArc(rz, start, sweep * f, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.05
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(startAngle: start, endAngle: start + sweep, colors: [b, accent]).createShader(rz));
    // ticks + numbers
    final majorEvery = max > 160 ? 20 : 10;
    for (var v = 0; v <= max; v += 5) {
      final a = start + sweep * v / max;
      final major = v % majorEvery == 0;
      final lit = v / max <= f;
      canvas.drawLine(
          _p(c, r * (major ? 0.70 : 0.75), a),
          _p(c, r * 0.81, a),
          Paint()
            ..color = (v / max > 0.82) ? const Color(0xFFFF5A5A) : (lit ? accent : Colors.white70)
            ..strokeWidth = major ? 4 : 2
            ..strokeCap = StrokeCap.round);
      if (major) _label(canvas, '$v', _p(c, r * 0.58, a), r * 0.075, Colors.white.withOpacity(0.85));
    }
    if (sport) {
      // shift lights
      for (var i = 0; i < 9; i++) {
        final on = f > i / 9;
        final col = i < 4 ? const Color(0xFF30D158) : (i < 7 ? const Color(0xFFFFD60A) : const Color(0xFFFF3B30));
        canvas.drawCircle(c + Offset((i - 4) * r * 0.085, -r * 0.30), r * 0.026,
            Paint()..color = on ? col : Colors.white12);
      }
    }
    // needle
    final na = start + sweep * f;
    final needle = Paint()
      ..color = sport ? const Color(0xFFFF2D2D) : const Color(0xFFFF8A1F)
      ..strokeWidth = r * 0.025
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(_p(c, -r * 0.12, na), _p(c, r * 0.78, na),
        Paint()
          ..color = needle.color.withOpacity(0.35)
          ..strokeWidth = r * 0.06
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawLine(_p(c, -r * 0.12, na), _p(c, r * 0.78, na), needle);
    canvas.drawCircle(c, r * 0.07,
        Paint()..shader = const RadialGradient(colors: [Color(0xFF8A8F96), Color(0xFF202327)]).createShader(Rect.fromCircle(center: c, radius: r * 0.07)));
  }

  void _digital(Canvas canvas, Offset c, double r) {
    const n = 60;
    for (var i = 0; i < n; i++) {
      final a = start + sweep * i / (n - 1);
      final lit = i / (n - 1) <= f;
      final t = i / (n - 1);
      final col = t < 0.6 ? Color.lerp(b, accent, t / 0.6)! : Color.lerp(accent, const Color(0xFFFF3B30), (t - 0.6) / 0.4)!;
      canvas.drawLine(_p(c, r * 0.80, a), _p(c, r * 0.97, a),
          Paint()
            ..color = lit ? col : Colors.white.withOpacity(0.07)
            ..strokeWidth = r * 0.045
            ..strokeCap = StrokeCap.round);
    }
    canvas.drawCircle(c, r * 0.72, Paint()..color = Colors.black.withOpacity(0.35));
  }

  void _neon(Canvas canvas, Offset c, double r) {
    final rect = Rect.fromCircle(center: c, radius: r * 0.86);
    canvas.drawArc(rect, start, sweep, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.07
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withOpacity(0.06));
    for (final w in [0.22, 0.12, 0.06]) {
      canvas.drawArc(rect, start, math.max(0.001, sweep * f), false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * w
            ..strokeCap = StrokeCap.round
            ..shader = SweepGradient(startAngle: start, endAngle: start + sweep, colors: [b, accent, warn ? const Color(0xFFFF3B30) : accent])
                .createShader(rect)
            ..maskFilter = w > 0.1 ? MaskFilter.blur(BlurStyle.normal, r * w / 2) : null);
    }
    final end = _p(c, r * 0.86, start + sweep * f);
    canvas.drawCircle(end, r * 0.045, Paint()..color = Colors.white);
  }

  void _minimal(Canvas canvas, Offset c, double r) {
    final y = c.dy + r * 0.62;
    final w = r * 1.4;
    final rr = RRect.fromLTRBR(c.dx - w / 2, y, c.dx + w / 2, y + 10, const Radius.circular(10));
    canvas.drawRRect(rr, Paint()..color = Colors.white.withOpacity(0.1));
    canvas.drawRRect(
        RRect.fromLTRBR(c.dx - w / 2, y, c.dx - w / 2 + w * f, y + 10, const Radius.circular(10)),
        Paint()..shader = LinearGradient(colors: [b, accent]).createShader(rr.outerRect));
  }

  @override
  bool shouldRepaint(covariant _GaugePainter o) => o.f != f || o.style != style || o.accent != accent || o.max != max;
}

// ============================================================ car scene
class _CarScenePainter extends CustomPainter {
  final String model;
  final Color color;
  final bool road;
  final double roadPos;
  final double wheel;
  final bool lights;
  final bool brake;
  final Color accent;
  _CarScenePainter({
    required this.model,
    required this.color,
    required this.road,
    required this.roadPos,
    required this.wheel,
    required this.lights,
    required this.brake,
    required this.accent,
  });

  // (x, y) outline points as fractions of car length / body height, rear → front.
  static const _shapes = <String, List<List<double>>>{
    'sedan': [[0, .18], [.01, .5], [.05, .58], [.2, .62], [.33, .97], [.4, 1], [.58, 1], [.66, .9], [.75, .64], [.93, .55], [.99, .46], [1, .2]],
    'suv': [[0, .2], [.01, .88], [.06, .98], [.12, 1], [.62, 1], [.67, .94], [.77, .7], [.96, .62], [1, .5], [1, .22]],
    'hatch': [[0, .2], [.01, .8], [.05, .95], [.14, 1], [.56, 1], [.63, .9], [.73, .66], [.93, .56], [.99, .46], [1, .2]],
    'sport': [[0, .26], [.02, .55], [.12, .6], [.32, .9], [.42, .95], [.55, .93], [.68, .6], [.95, .42], [1, .32], [1, .2]],
    'pickup': [[0, .24], [0, .62], [.36, .62], [.38, .97], [.42, 1], [.6, 1], [.64, .94], [.74, .68], [.95, .6], [1, .5], [1, .24]],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final ground = h * 0.86;
    // road
    if (road) {
      canvas.drawRect(Rect.fromLTWH(0, ground, w, h - ground), Paint()..color = const Color(0xFF1B1D22));
      final dash = Paint()
        ..color = Colors.white.withOpacity(0.55)
        ..strokeWidth = 4;
      final off = roadPos % 80;
      for (var x = -off; x < w; x += 80) {
        canvas.drawLine(Offset(w - x, ground + (h - ground) / 2), Offset(w - x - 40, ground + (h - ground) / 2), dash);
      }
      canvas.drawLine(Offset(0, ground), Offset(w, ground), Paint()..color = Colors.white24..strokeWidth = 2);
    }
    final pts = _shapes[model] ?? _shapes['sedan']!;
    final len = math.min(w * 0.86, h * 2.9);
    final left = (w - len) / 2;
    final wheelR = len * 0.085;
    final bodyBottom = ground - wheelR * 0.55;
    final bodyH = len * (model == 'suv' || model == 'pickup' ? 0.30 : (model == 'sport' ? 0.22 : 0.26));
    Offset at(List<double> p) => Offset(left + p[0] * len, bodyBottom - p[1] * bodyH);

    // shadow
    canvas.drawOval(Rect.fromCenter(center: Offset(w / 2, ground + 2), width: len * 1.02, height: wheelR * 0.5),
        Paint()..color = Colors.black.withOpacity(0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    // body
    final body = Path()..moveTo(left + len * 0.02, bodyBottom);
    for (final p in pts) {
      body.lineTo(at(p).dx, at(p).dy);
    }
    body
      ..lineTo(left + len, bodyBottom)
      ..close();
    final bodyRect = body.getBounds();
    canvas.drawPath(
        body,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(color, Colors.white, 0.35)!, color, Color.lerp(color, Colors.black, 0.45)!],
            stops: const [0, 0.45, 1],
          ).createShader(bodyRect)
          ..style = PaintingStyle.fill
          ..strokeJoin = StrokeJoin.round);
    canvas.drawPath(body, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = Colors.black.withOpacity(0.35)..strokeJoin = StrokeJoin.round);
    // belt line highlight
    canvas.drawLine(Offset(left + len * 0.06, bodyBottom - bodyH * 0.5), Offset(left + len * 0.9, bodyBottom - bodyH * 0.5),
        Paint()..color = Colors.white.withOpacity(0.25)..strokeWidth = 2);

    // glass (cabin): from roof-start to windshield base, inset
    final roofIdx = pts.indexWhere((p) => p[1] >= 0.9);
    if (roofIdx > 0) {
      final win = Path();
      final a = at(pts[roofIdx - 1]);
      win.moveTo(a.dx + len * 0.02, a.dy - bodyH * 0.02);
      for (var i = roofIdx; i < pts.length && pts[i][1] >= 0.85; i++) {
        final p = at(pts[i]);
        win.lineTo(p.dx, p.dy + bodyH * 0.07);
      }
      final lastRoof = pts.lastIndexWhere((p) => p[1] >= 0.85);
      final ws = at(pts[math.min(lastRoof + 1, pts.length - 1)]);
      win
        ..lineTo(ws.dx - len * 0.025, ws.dy - bodyH * 0.02)
        ..lineTo(a.dx + len * 0.02, ws.dy - bodyH * 0.02)
        ..close();
      canvas.drawPath(
          win,
          Paint()
            ..shader = LinearGradient(colors: [const Color(0xFF0E1A24), const Color(0xFF3A5568).withOpacity(0.9)])
                .createShader(win.getBounds()));
      // B-pillar
      final wb = win.getBounds();
      canvas.drawLine(Offset(wb.center.dx + len * 0.02, wb.top + 2), Offset(wb.center.dx + len * 0.02, wb.bottom - 1),
          Paint()..color = Color.lerp(color, Colors.black, 0.6)!..strokeWidth = len * 0.012);
    }

    // lights
    final front = at(pts[pts.length - 3]);
    final rear = at(pts[1]);
    final head = Offset(left + len * 0.975, front.dy + bodyH * 0.08);
    canvas.drawOval(Rect.fromCenter(center: head, width: len * 0.05, height: bodyH * 0.12), Paint()..color = const Color(0xFFEAF6FF));
    if (lights) {
      final beam = Path()
        ..moveTo(head.dx, head.dy - 4)
        ..lineTo(w, head.dy - bodyH * 0.25)
        ..lineTo(w, ground)
        ..close();
      canvas.drawPath(beam, Paint()..shader = LinearGradient(colors: [Colors.white.withOpacity(0.35), Colors.white.withOpacity(0)]).createShader(beam.getBounds()));
    }
    final tail = Offset(left + len * 0.012, rear.dy + bodyH * 0.05);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: tail, width: len * 0.025, height: bodyH * 0.14), const Radius.circular(3)),
        Paint()..color = brake ? const Color(0xFFFF1A1A) : const Color(0xFF9B111E));
    if (brake) {
      canvas.drawCircle(tail, len * 0.05, Paint()..color = const Color(0x66FF1A1A)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    }

    // wheels (spin with speed)
    for (final x in [0.2, 0.8]) {
      final wc = Offset(left + len * x, ground - wheelR);
      canvas.drawCircle(wc, wheelR * 1.12, Paint()..color = const Color(0xFF0B0B0B)); // arch
      canvas.drawCircle(wc, wheelR, Paint()..color = const Color(0xFF1A1A1A));
      canvas.drawCircle(wc, wheelR * 0.62,
          Paint()..shader = const RadialGradient(colors: [Color(0xFFDADDE1), Color(0xFF6C7178)]).createShader(Rect.fromCircle(center: wc, radius: wheelR * 0.62)));
      final spoke = Paint()
        ..color = const Color(0xFF3A3D42)
        ..strokeWidth = wheelR * 0.12
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k < 5; k++) {
        final a = wheel + k * 2 * math.pi / 5;
        canvas.drawLine(wc, wc + Offset(math.cos(a), math.sin(a)) * wheelR * 0.58, spoke);
      }
      canvas.drawCircle(wc, wheelR * 0.14, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(covariant _CarScenePainter o) => true;
}

// ================================================================ tiles
class _Tiles extends StatelessWidget {
  final bool warn;
  final bool mph;
  const _Tiles({required this.warn, required this.mph});

  @override
  Widget build(BuildContext context) {
    final st = Settings.instance;
    final g = Gps.instance;
    final f = mph ? 0.621371 : 1.0;
    final unit = mph ? 'mph' : 'كم/س';
    final dist = mph ? '${(g.distanceKm * f).toStringAsFixed(1)} mi' : '${g.distanceKm.toStringAsFixed(1)} كم';
    String dur(Duration d) => '${d.inHours > 0 ? '${d.inHours}:' : ''}${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    final next = Prayer.instance.next;
    final values = <String, String>{
      'trip': dist,
      'time': dur(g.tripTime),
      'max': '${(g.maxKmh * f).round()} $unit',
      'avg': '${(g.avgKmh * f).round()} $unit',
      'heading': g.compass,
      'alt': '${g.altitude.round()} م',
      'clock': fmtClock(DateTime.now(), h24: st.clock24, seconds: true),
      'z100': g.zeroTo100 == null ? '—' : '${g.zeroTo100!.toStringAsFixed(1)} ث',
      'gps': g.hasFix ? '${g.satsUsed}/${g.sats} · ±${g.accuracy.round()}م' : 'بيدوّر…',
      'prayer': '${next.$1} ${fmtCountdown(next.$2.difference(DateTime.now()))}',
      'hijri': hijriText(DateTime.now(), st.hijriOffset),
    };
    final chosen = [for (final t in carTilesAll) if (st.carTiles.contains(t.$1)) t];
    return LayoutBuilder(builder: (context, c) {
      final cols = chosen.length <= 4 ? 2 : 3;
      return GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: cols,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: (c.maxWidth / cols) / math.max(70, (c.maxHeight - 10) / ((chosen.length / cols).ceil().clamp(1, 4))),
        children: [
          for (final t in chosen)
            GestureDetector(
              onLongPress: t.$1 == 'trip' || t.$1 == 'time' || t.$1 == 'max' ? g.resetTrip : null,
              child: Glass(
                blur: false,
                radius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                borderColor: warn && t.$1 == 'max' ? const Color(0xFFFF3B3B) : null,
                child: Row(children: [
                  Icon(t.$3, color: AppColors.gold, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(values[t.$1] ?? '—',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
                        ),
                        Text(t.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
        ],
      );
    });
  }
}

// ========================================================== mini player
class _MiniPlayer extends StatelessWidget {
  final Widget Function(Widget) swap;
  final VoidCallback next;
  final VoidCallback prev;
  const _MiniPlayer({required this.swap, required this.next, required this.prev});

  @override
  Widget build(BuildContext context) {
    final p = Player.instance;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) => Glass(
        radius: 30,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(children: [
          ReciterAvatar('', photoId: p.reciterId ?? p.sheikhId ?? p.azkarOwner, size: 64, glow: p.playing),
          const SizedBox(width: 16),
          Expanded(
            child: swap(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.hasMedia ? p.title : 'اضغط تشغيل',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              Text(p.hasMedia ? p.subtitle : '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, color: AppColors.gold)),
            ])),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(children: [
              GlassButton(icon: Icons.skip_previous_rounded, size: 76, onTap: prev),
              const SizedBox(width: 14),
              StreamBuilder<PlayerState>(
                stream: p.audio.playerStateStream,
                builder: (context, s) => GlassButton(
                  icon: (s.data?.playing ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 96,
                  primary: true,
                  onTap: p.toggle,
                ),
              ),
              const SizedBox(width: 14),
              GlassButton(icon: Icons.skip_next_rounded, size: 76, onTap: next),
            ]),
          ),
        ]),
      ),
    );
  }
}
