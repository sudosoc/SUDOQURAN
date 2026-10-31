import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_audio/just_audio.dart';

import '../services/gps.dart';
import '../services/player.dart';
import '../services/prayer.dart';
import '../services/settings.dart';
import 'drive_mode.dart';
import 'glass.dart';
import 'settings_widgets.dart';

// ================================================================ catalogues
const carGauges = <(String, String, String)>[
  ('halo', 'هالة', 'مذنّب نور بيلف ومعاه ذيل'),
  ('hud', 'شاشة طيار', 'شريط أرقام بيجري زي الطيارات'),
  ('liquid', 'سايل', 'موج بيعلى مع السرعة'),
  ('orbit', 'مدارات', 'كواكب بتلف أسرع كل ما تسرع'),
  ('equalizer', 'إيكولايزر', 'أعمدة بترقص على السرعة'),
  ('star', 'نجمة إسلامية', 'نجمة ثمانية بتفتّح وتلف'),
  ('segments', 'بلوكات', 'قطع مضيئة ثلاثية الأبعاد'),
  ('radar', 'رادار', 'مسح رادار ونقط بتلمع'),
  ('zen', 'زِن', 'رقم عملاق وخط رفيع بس'),
  ('tunnel', 'نفق', 'نفق سداسي بيجري ناحيتك'),
];
const carFxs = <(String, String)>[
  ('warp', 'نجوم سرعة'),
  ('flow', 'خطوط ضوء'),
  ('aurora', 'شفق'),
  ('dots', 'نبض نقط'),
  ('none', 'بدون'),
];
const carLayouts = <(String, String)>[
  ('left', 'العداد شمال'),
  ('right', 'العداد يمين'),
  ('center', 'العداد في النص'),
  ('hero', 'العداد كبير'),
];
const carTileStyles = <(String, String)>[
  ('glass', 'زجاج'),
  ('line', 'إطار مضيء'),
  ('bare', 'خط جانبي'),
];
const carAccents = <(int, String)>[
  (0, 'لون الثيم'),
  (0xFF00E5FF, 'سماوي'),
  (0xFFFF2D55, 'أحمر'),
  (0xFF30D158, 'أخضر'),
  (0xFFBF5AF2, 'بنفسجي'),
  (0xFFFF9F0A, 'برتقالي'),
  (0xFFFFD60A, 'أصفر'),
  (0xFFFFFFFF, 'أبيض'),
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

Color carAccentColor() {
  final a = Settings.instance.carAccent;
  return a == 0 ? AppColors.gold : Color(a);
}

double _demoSpeed(double t, double max) =>
    math.max(0.0, max * 0.62 * (0.5 - 0.5 * math.cos(t * 0.32)) + max * 0.04 * math.sin(t * 1.9));

// ================================================================ animation clock
/// Ticks every frame; painters repaint off it without rebuilding widgets.
class DashClock extends ChangeNotifier {
  double t = 0;
  double v = 0;
  double accel = 0; // km/h per second

  void step(double dt, double target) {
    t += dt;
    final prev = v;
    v += (target - v) * (1 - math.exp(-dt * 5));
    if (v < 0.05) v = 0;
    final a = dt > 0 ? (v - prev) / dt : 0.0;
    accel += (a - accel) * (1 - math.exp(-dt * 3));
    notifyListeners();
  }
}

class GaugeCfg {
  final String style;
  final double max;
  final Color accent;
  final Color base;
  final String unit;
  final double limit;
  const GaugeCfg({
    required this.style,
    required this.max,
    required this.accent,
    required this.base,
    required this.unit,
    this.limit = 0,
  });
}

// ================================================================ dashboard
/// "عداد السرعة" drive style: live GPS speed, animated gauge, trip computer.
class CarDashBody extends StatefulWidget {
  final Widget Function(Widget) swap;
  final VoidCallback next;
  final VoidCallback prev;
  final bool preview;
  const CarDashBody({super.key, required this.swap, required this.next, required this.prev, this.preview = false});

  @override
  State<CarDashBody> createState() => _CarDashBodyState();
}

class _CarDashBodyState extends State<CarDashBody> with SingleTickerProviderStateMixin {
  final _clock = DashClock();
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (!widget.preview) Gps.instance.start();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration e) {
    final dt = ((e - _last).inMicroseconds / 1e6).clamp(0.0, 0.1).toDouble();
    _last = e;
    final st = Settings.instance;
    final f = st.carMph ? 0.621371 : 1.0;
    final max = st.carMax * (st.carMph ? 0.65 : 1.0);
    final target = (widget.preview || st.carDemo) ? _demoSpeed(_clock.t, max) : Gps.instance.speedKmh * f;
    _clock.step(dt, target);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    if (!widget.preview) Gps.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Settings.instance,
      builder: (context, _) {
        final st = Settings.instance;
        final mph = st.carMph;
        final f = mph ? 0.621371 : 1.0;
        final cfg = GaugeCfg(
          style: st.carGauge,
          max: st.carMax * (mph ? 0.65 : 1.0),
          accent: carAccentColor(),
          base: AppColors.emerald,
          unit: mph ? 'mph' : 'كم/س',
          limit: st.carLimit * f,
        );
        final gauge = Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: RepaintBoundary(
              child: Stack(children: [
                Positioned.fill(child: CustomPaint(painter: GaugePainter(_clock, cfg))),
                if (!widget.preview && !st.carDemo) const _GpsChip(),
              ]),
            ),
          ),
        );
        final ids = [for (final t in carTilesAll) if (st.carTiles.contains(t.$1)) t.$1];
        final tiles = _Tiles(accent: cfg.accent, style: st.carTileStyle, mph: mph);
        final Widget dash;
        switch (st.carLayout) {
          case 'center':
            final half = (ids.length / 2).ceil();
            dash = Row(children: [
              Expanded(flex: 3, child: tiles.grid(ids.sublist(0, half), 1)),
              const SizedBox(width: 12),
              Expanded(flex: 5, child: gauge),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: tiles.grid(ids.sublist(half), 1)),
            ]);
          case 'hero':
            dash = Column(children: [
              Expanded(child: gauge),
              if (ids.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(height: 118, child: tiles.grid(ids, ids.length)),
              ],
            ]);
          default:
            final g = Expanded(flex: 5, child: gauge);
            final t = Expanded(flex: 5, child: tiles.grid(ids, ids.length <= 3 ? 1 : 2));
            // RTL row: first child sits on the right.
            dash = Row(children: st.carLayout == 'right' ? [g, const SizedBox(width: 16), t] : [t, const SizedBox(width: 16), g]);
        }
        return Stack(children: [
          if (st.carFx != 'none')
            Positioned.fill(
              child: RepaintBoundary(child: CustomPaint(painter: FxPainter(_clock, st.carFx, cfg))),
            ),
          Column(children: [
            Expanded(child: dash),
            if (!widget.preview && st.carPlayer) ...[
              const SizedBox(height: 12),
              _MiniPlayer(swap: widget.swap, next: widget.next, prev: widget.prev, accent: cfg.accent),
            ],
          ]),
        ]);
      },
    );
  }
}

class _GpsChip extends StatelessWidget {
  const _GpsChip();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Gps.instance,
      builder: (context, _) {
        final g = Gps.instance;
        final msg = g.error ?? (g.hasFix ? null : 'بيدوّر على GPS…');
        if (msg == null) return const SizedBox.shrink();
        return Align(
          alignment: const Alignment(0, 0.98),
          child: GestureDetector(
            onTap: () {
              g.stop();
              g.start();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.black.withOpacity(0.7),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.gps_not_fixed_rounded, color: AppColors.gold, size: 20),
                const SizedBox(width: 8),
                Text(msg, style: const TextStyle(fontSize: 16)),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ================================================================ gauge painter
class GaugePainter extends CustomPainter {
  final DashClock k;
  final GaugeCfg cfg;
  GaugePainter(this.k, this.cfg) : super(repaint: k);

  static const a0 = math.pi * 0.75;
  static const sw = math.pi * 1.5;

  late Canvas _c;
  late Offset c;
  late double r;
  late double f;
  late double t;
  late Color acc;
  late bool warn;

  @override
  void paint(Canvas canvas, Size size) {
    _c = canvas;
    c = size.center(Offset.zero);
    r = size.shortestSide / 2 - 4;
    if (r <= 4) return;
    t = k.t;
    f = (k.v / cfg.max).clamp(0.0, 1.0).toDouble();
    warn = cfg.limit > 0 && k.v > cfg.limit;
    acc = warn
        ? Color.lerp(const Color(0xFFFF2D2D), Colors.white, 0.3 * (0.5 + 0.5 * math.sin(t * 10)))!
        : cfg.accent;
    switch (cfg.style) {
      case 'hud':
        _hud();
      case 'liquid':
        _liquid();
      case 'orbit':
        _orbit();
      case 'equalizer':
        _equalizer();
      case 'star':
        _star();
      case 'segments':
        _segments();
      case 'radar':
        _radar();
      case 'zen':
        _zen();
      case 'tunnel':
        _tunnel();
      default:
        _halo();
    }
  }

  // ---------------------------------------------------------------- helpers
  Offset p(double rad, double a) => c + Offset(math.cos(a), math.sin(a)) * rad;

  Paint stroke(double w, Color col, {bool round = true}) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..color = col
    ..strokeCap = round ? StrokeCap.round : StrokeCap.butt;

  Paint glow(Paint p, double s) => p..maskFilter = MaskFilter.blur(BlurStyle.normal, s);

  Shader sweepShader(double rad, List<Color> cols) => SweepGradient(
        startAngle: 0,
        endAngle: sw,
        colors: cols,
        transform: const GradientRotation(a0),
      ).createShader(Rect.fromCircle(center: c, radius: rad));

  Color ramp(double x) => x < 0.7
      ? Color.lerp(cfg.base, acc, x / 0.7)!
      : Color.lerp(acc, const Color(0xFFFF3B30), ((x - 0.7) / 0.3).clamp(0.0, 1.0).toDouble())!;

  void text(String s, Offset at, double size, Color col,
      {FontWeight w = FontWeight.w700, double blur = 0, double spacing = 0, bool italic = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          color: col,
          fontWeight: w,
          letterSpacing: spacing,
          height: 1,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          fontFeatures: const [FontFeature.tabularFigures()],
          shadows: blur > 0 ? [Shadow(color: acc.withOpacity(0.8), blurRadius: blur)] : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(_c, at - Offset(tp.width / 2, tp.height / 2));
  }

  void number({double scale = 0.5, FontWeight w = FontWeight.w300, double blur = 0, bool italic = false, Offset? at}) {
    final o = at ?? c;
    text('${k.v.round()}', o, r * scale, warn ? acc : Colors.white, w: w, blur: blur, italic: italic);
    text(cfg.unit, o + Offset(0, r * scale * 0.62 + r * 0.07), r * 0.085, acc, spacing: 3);
  }

  Path poly(int n, double rad, double rot) {
    final path = Path();
    for (var j = 0; j < n; j++) {
      final pt = p(rad, rot + j * 2 * math.pi / n);
      if (j == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    return path..close();
  }

  // ---------------------------------------------------------------- halo
  void _halo() {
    final R = r * 0.86;
    final rect = Rect.fromCircle(center: c, radius: R);
    _c.drawArc(rect, a0, sw, false, stroke(r * 0.1, Colors.white.withOpacity(0.05)));
    final rot = t * (0.15 + f * 2.2);
    for (var i = 0; i < 72; i++) {
      final a = rot + i * math.pi * 2 / 72;
      _c.drawLine(p(r * 0.63, a), p(r * 0.67, a), stroke(2, Colors.white.withOpacity(i % 6 == 0 ? 0.35 : 0.1)));
    }
    for (var i = 0; i <= 20; i++) {
      final x = i / 20;
      _c.drawCircle(p(r * 0.74, a0 + sw * x), i % 5 == 0 ? 3.5 : 2, Paint()..color = x <= f ? acc : Colors.white24);
    }
    if (f > 0.002) {
      _c.drawArc(rect, a0, sw * f, false, glow(stroke(r * 0.16, acc.withOpacity(0.35)), r * 0.08));
      _c.drawArc(rect, a0, sw * f, false,
          stroke(r * 0.1, Colors.white)..shader = sweepShader(R, [cfg.base, acc, Color.lerp(acc, Colors.white, 0.4)!]));
    }
    final ha = a0 + sw * f;
    for (var i = 1; i <= 18; i++) {
      final a = ha - i * 0.035 * (0.4 + f);
      if (a < a0) break;
      final jit = math.sin(t * 6 + i * 1.7) * r * 0.03;
      _c.drawCircle(p(R + jit, a), r * 0.022 * (1 - i / 20), Paint()..color = acc.withOpacity(0.75 * (1 - i / 18)));
    }
    _c.drawCircle(p(R, ha), r * 0.08, glow(Paint()..color = acc.withOpacity(0.85), r * 0.06));
    _c.drawCircle(p(R, ha), r * 0.04, Paint()..color = Colors.white);
    number(scale: 0.5, w: FontWeight.w200);
  }

  // ---------------------------------------------------------------- hud
  void _hud() {
    final line = stroke(2.5, acc.withOpacity(0.85), round: false);
    final b = r * 0.95, len = r * 0.2;
    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        final o = c + Offset(sx * b, sy * b);
        _c.drawLine(o, o + Offset(-sx * len, 0), line);
        _c.drawLine(o, o + Offset(0, -sy * len), line);
      }
    }
    // pitch ladder scrolls with speed, tilts with acceleration
    final tilt = (k.accel / 15).clamp(-1.0, 1.0).toDouble() * 0.2;
    final gap = r * 0.22;
    final off = (t * (6 + k.v * 1.4)) % gap;
    _c.save();
    _c.translate(c.dx, c.dy);
    _c.rotate(tilt);
    for (var i = -5; i <= 4; i++) {
      final y = i * gap + off;
      final al = (1 - y.abs() / (r * 0.85)).clamp(0.0, 1.0).toDouble() * 0.45;
      if (al <= 0) continue;
      final pp = stroke(2, acc.withOpacity(al), round: false);
      _c.drawLine(Offset(-r * 0.6, y), Offset(-r * 0.36, y), pp);
      _c.drawLine(Offset(r * 0.36, y), Offset(r * 0.6, y), pp);
      _c.drawLine(Offset(-r * 0.36, y), Offset(-r * 0.36, y + r * 0.03), pp);
      _c.drawLine(Offset(r * 0.36, y), Offset(r * 0.36, y + r * 0.03), pp);
    }
    _c.restore();
    // speed tape (left)
    final tx = c.dx - r * 0.74;
    final half = r * 0.68;
    final px = half / 40;
    _c.save();
    _c.clipRect(Rect.fromLTRB(tx - r * 0.22, c.dy - half, tx + r * 0.1, c.dy + half));
    final startV = ((k.v - 40) / 5).floor() * 5;
    for (var v = startV; v <= k.v + 40; v += 5) {
      if (v < 0) continue;
      final y = c.dy - (v - k.v) * px;
      final al = (1 - (y - c.dy).abs() / half).clamp(0.0, 1.0).toDouble();
      final major = v % 10 == 0;
      _c.drawLine(Offset(tx, y), Offset(tx + (major ? r * 0.08 : r * 0.04), y), stroke(2, Colors.white.withOpacity(al * 0.8)));
      if (major) text('$v', Offset(tx - r * 0.1, y), r * 0.06, Colors.white.withOpacity(al));
    }
    _c.restore();
    // G-meter (right)
    final gx = c.dx + r * 0.76;
    final gh = r * 0.6;
    _c.drawLine(Offset(gx, c.dy - gh), Offset(gx, c.dy + gh), stroke(6, Colors.white.withOpacity(0.08)));
    final g = (k.accel / 20).clamp(-1.0, 1.0).toDouble();
    _c.drawLine(Offset(gx, c.dy), Offset(gx, c.dy - g * gh), stroke(6, g >= 0 ? cfg.base : const Color(0xFFFF453A)));
    _c.drawLine(Offset(gx - r * 0.04, c.dy), Offset(gx + r * 0.04, c.dy), stroke(2, Colors.white54));
    text('G', Offset(gx, c.dy + gh + r * 0.07), r * 0.06, acc);
    // readout box
    final box = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: r * 0.95, height: r * 0.5), Radius.circular(r * 0.06));
    _c.drawRRect(box, Paint()..color = Colors.black.withOpacity(0.6));
    _c.drawRRect(box, glow(stroke(6, acc.withOpacity(0.4), round: false), 6));
    _c.drawRRect(box, stroke(2.5, acc, round: false));
    final chev = Path()
      ..moveTo(c.dx - r * 0.475, c.dy - r * 0.06)
      ..lineTo(c.dx - r * 0.56, c.dy)
      ..lineTo(c.dx - r * 0.475, c.dy + r * 0.06)
      ..close();
    _c.drawPath(chev, Paint()..color = acc);
    text('${k.v.round()}', c, r * 0.36, warn ? acc : Colors.white, w: FontWeight.w800);
    text(cfg.unit, c + Offset(0, r * 0.33), r * 0.085, acc, spacing: 3);
    // segmented progress
    const n = 30;
    final w = r * 1.2 / n;
    for (var i = 0; i < n; i++) {
      final x0 = c.dx - r * 0.6 + i * w;
      _c.drawRect(Rect.fromLTWH(x0 + 1, c.dy + r * 0.5, w - 3, r * 0.05),
          Paint()..color = i / n < f ? ramp(i / n) : Colors.white.withOpacity(0.08));
    }
  }

  // ---------------------------------------------------------------- liquid
  void _liquid() {
    final R = r * 0.86;
    _c.drawCircle(c, R + r * 0.06, glow(stroke(r * 0.03, acc.withOpacity(0.5)), r * 0.04));
    _c.drawCircle(c, R + r * 0.05, stroke(2, acc.withOpacity(0.8)));
    _c.save();
    _c.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: R)));
    _c.drawCircle(c, R, Paint()..color = Colors.black.withOpacity(0.35));
    final lvl = c.dy + R - 2 * R * (0.04 + f * 0.9);
    final spd = 1.2 + f * 6;
    for (final layer in [1, 0]) {
      final path = Path()..moveTo(c.dx - R, c.dy + R);
      for (var x = -R; x <= R + 6; x += 6) {
        final y = lvl +
            math.sin(x / R * math.pi * (layer == 0 ? 1.6 : 2.3) + t * spd * (layer == 0 ? 1 : -1.3) + layer * 2) *
                R *
                (0.035 + f * 0.03) -
            layer * R * 0.02;
        path.lineTo(c.dx + x, y);
      }
      path
        ..lineTo(c.dx + R, c.dy + R)
        ..close();
      _c.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [acc.withOpacity(layer == 0 ? 0.95 : 0.45), cfg.base.withOpacity(layer == 0 ? 0.95 : 0.35)],
            ).createShader(Rect.fromLTRB(c.dx - R, lvl - R * 0.1, c.dx + R, c.dy + R)));
    }
    final bottom = c.dy + R;
    for (var i = 0; i < 12; i++) {
      final ph = (t * (0.12 + f * 0.5) * (1 + (i % 3) * 0.4) + i * 0.137) % 1.0;
      final y = bottom - ph * (bottom - lvl);
      final x = c.dx + math.sin(i * 12.9898) * R * 0.7 + math.sin(t * 2 + i) * 4;
      _c.drawCircle(Offset(x, y), 2.0 + (i % 4), stroke(1.5, Colors.white.withOpacity(0.5 * (1 - ph))));
    }
    _c.drawOval(Rect.fromCenter(center: c + Offset(-R * 0.3, -R * 0.55), width: R * 0.9, height: R * 0.35),
        Paint()..color = Colors.white.withOpacity(0.06));
    _c.restore();
    number(scale: 0.48, w: FontWeight.w800, blur: 12);
  }

  // ---------------------------------------------------------------- orbit
  void _orbit() {
    final rect = Rect.fromCircle(center: c, radius: r * 0.97);
    _c.drawArc(rect, a0, sw, false, stroke(5, Colors.white.withOpacity(0.06)));
    if (f > 0.002) {
      _c.drawArc(rect, a0, sw * f, false, glow(stroke(10, acc.withOpacity(0.4)), 8));
      _c.drawArc(rect, a0, sw * f, false, stroke(5, acc));
    }
    final pulse = 0.5 + 0.5 * math.sin(t * (2 + f * 6));
    _c.drawCircle(
        c,
        r * 0.42,
        Paint()
          ..shader = RadialGradient(colors: [acc.withOpacity(0.22 + 0.1 * pulse), Colors.transparent])
              .createShader(Rect.fromCircle(center: c, radius: r * 0.42)));
    for (var i = 0; i < 3; i++) {
      final tilt = i * math.pi / 3 + t * 0.05;
      final rx = r * 0.82, ry = r * 0.82 * 0.34;
      _c.save();
      _c.translate(c.dx, c.dy);
      _c.rotate(tilt);
      _c.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), stroke(1.5, Colors.white.withOpacity(0.14)));
      final w = (0.5 + f * 5.0) * (1 + i * 0.35);
      final th = t * w + i * 2.1;
      for (var j = 12; j >= 1; j--) {
        final a = th - j * 0.07;
        _c.drawCircle(Offset(math.cos(a) * rx, math.sin(a) * ry), r * 0.03 * (1 - j / 14),
            Paint()..color = acc.withOpacity(0.55 * (1 - j / 13)));
      }
      final head = Offset(math.cos(th) * rx, math.sin(th) * ry);
      _c.drawCircle(head, r * 0.06, glow(Paint()..color = acc.withOpacity(0.7), r * 0.05));
      _c.drawCircle(head, r * 0.028, Paint()..color = Colors.white);
      _c.restore();
    }
    number(scale: 0.42, w: FontWeight.w700, blur: 18);
  }

  // ---------------------------------------------------------------- equalizer
  void _equalizer() {
    const n = 64;
    for (var i = 0; i < n; i++) {
      final x = i / (n - 1);
      final a = a0 + sw * x;
      final lit = x <= f;
      final wob = 0.7 + 0.3 * math.sin(t * (6 + f * 10) + i * 0.55) * math.cos(t * 2.3 + i * 0.21);
      final len = lit ? r * (0.1 + 0.2 * x) * wob : r * 0.035;
      final col = lit ? ramp(x) : Colors.white.withOpacity(0.1);
      _c.drawLine(p(r * 0.62, a), p(r * 0.62 + len, a), stroke(r * 0.032, col));
      if (lit) _c.drawCircle(p(r * 0.62 + len + r * 0.035, a), r * 0.012, Paint()..color = col.withOpacity(0.8));
    }
    _c.drawCircle(c, r * 0.56, stroke(1.5, acc.withOpacity(0.35)));
    _c.drawCircle(c, r * 0.5, stroke(1, Colors.white.withOpacity(0.08)));
    number(scale: 0.46, w: FontWeight.w600);
  }

  // ---------------------------------------------------------------- star
  Path _starPath(double rr, double rot) {
    final inner = rr * math.cos(math.pi / 4) / math.cos(math.pi / 8);
    final path = Path();
    for (var j = 0; j < 16; j++) {
      final pt = p(j.isEven ? rr : inner, rot + j * math.pi / 8 - math.pi / 2);
      if (j == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    return path..close();
  }

  void _star() {
    final rot = t * (0.04 + f * 0.7);
    final R = r * 0.8;
    final star = _starPath(R, rot);
    _c.drawPath(star, Paint()..color = Colors.white.withOpacity(0.03));
    final bloom = R * (0.15 + f * 0.95);
    _c.save();
    _c.clipPath(star);
    _c.drawCircle(
        c,
        bloom,
        Paint()
          ..shader = RadialGradient(
            colors: [acc.withOpacity(0.6), cfg.base.withOpacity(0.25), Colors.transparent],
            stops: const [0, 0.7, 1],
          ).createShader(Rect.fromCircle(center: c, radius: bloom)));
    _c.restore();
    _c.drawPath(star, glow(stroke(r * 0.03, acc.withOpacity(0.45)), r * 0.03));
    _c.drawPath(star, stroke(2.5, acc));
    for (final off in [0.0, math.pi / 4]) {
      _c.drawPath(poly(4, R * 0.6, -rot * 1.6 + off), stroke(1.5, Colors.white.withOpacity(0.2)));
    }
    _c.drawPath(_starPath(R * 0.32, -rot * 2), stroke(1.5, acc.withOpacity(0.5)));
    const n = 40;
    for (var j = 0; j < n; j++) {
      final x = j / n;
      final a = -math.pi / 2 + x * 2 * math.pi;
      final lit = x < f;
      final head = lit && (j + 1) / n >= f;
      final s = r * (head ? 0.036 + 0.01 * math.sin(t * 10) : 0.022);
      final o = p(r * 0.94, a);
      final ca = math.cos(a), sa = math.sin(a);
      final d = Path()
        ..moveTo(o.dx + ca * s * 1.6, o.dy + sa * s * 1.6)
        ..lineTo(o.dx - sa * s, o.dy + ca * s)
        ..lineTo(o.dx - ca * s * 1.6, o.dy - sa * s * 1.6)
        ..lineTo(o.dx + sa * s, o.dy - ca * s)
        ..close();
      _c.drawPath(d, Paint()..color = lit ? ramp(x) : Colors.white.withOpacity(0.1));
    }
    number(scale: 0.36, w: FontWeight.w800, blur: 14);
  }

  // ---------------------------------------------------------------- segments
  void _segments() {
    const n = 24;
    final R = r * 0.8;
    final rect = Rect.fromCircle(center: c, radius: R);
    final outer = Rect.fromCircle(center: c, radius: R + r * 0.095);
    final span = sw / n;
    for (var j = 0; j < n; j++) {
      final x0 = j / n;
      final lit = x0 < f;
      final head = lit && (j + 1) / n >= f;
      final col = lit ? ramp(x0) : Colors.white.withOpacity(0.06);
      final a = a0 + span * j + span * 0.1;
      if (head) {
        _c.drawArc(rect, a, span * 0.8, false,
            glow(stroke(r * 0.24, col.withOpacity(0.45 + 0.3 * math.sin(t * 12))), r * 0.06));
      }
      _c.drawArc(rect, a, span * 0.8, false, stroke(r * 0.17, col, round: false));
      _c.drawArc(outer, a, span * 0.8, false, stroke(2, Colors.white.withOpacity(lit ? 0.6 : 0.08), round: false));
    }
    final step = cfg.max > 160 ? 40 : 20;
    for (var v = 0; v <= cfg.max; v += step) {
      text('$v', p(r * 0.56, a0 + sw * v / cfg.max), r * 0.065, Colors.white.withOpacity(0.55));
    }
    if (cfg.limit > 0 && cfg.limit < cfg.max) {
      final a = a0 + sw * cfg.limit / cfg.max;
      _c.drawLine(p(R - r * 0.12, a), p(R + r * 0.12, a), stroke(4, const Color(0xFFFF3B30)));
    }
    number(scale: 0.42, w: FontWeight.w900, italic: true);
  }

  // ---------------------------------------------------------------- radar
  void _radar() {
    final R = r * 0.9;
    _c.drawCircle(
        c,
        R,
        Paint()
          ..shader = RadialGradient(colors: [cfg.base.withOpacity(0.14), Colors.black.withOpacity(0.45)])
              .createShader(Rect.fromCircle(center: c, radius: R)));
    for (var j = 1; j <= 4; j++) {
      _c.drawCircle(c, R * j / 4, stroke(1.2, acc.withOpacity(0.2)));
    }
    _c.drawLine(c - Offset(R, 0), c + Offset(R, 0), stroke(1, acc.withOpacity(0.15)));
    _c.drawLine(c - Offset(0, R), c + Offset(0, R), stroke(1, acc.withOpacity(0.15)));
    const wedge = math.pi / 2.5;
    final sa = (t * (0.9 + f * 4)) % (2 * math.pi);
    _c.save();
    _c.translate(c.dx, c.dy);
    _c.rotate(sa - wedge);
    _c.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: R),
        0,
        wedge,
        true,
        Paint()
          ..shader = SweepGradient(startAngle: 0, endAngle: wedge, colors: [Colors.transparent, acc.withOpacity(0.45)])
              .createShader(Rect.fromCircle(center: Offset.zero, radius: R)));
    _c.restore();
    _c.drawLine(c, p(R, sa), glow(stroke(5, acc.withOpacity(0.6)), 4));
    _c.drawLine(c, p(R, sa), stroke(2, acc));
    for (var j = 0; j < 7; j++) {
      final ba = (j * 2.39996) % (2 * math.pi);
      final br = R * (0.3 + ((j * 0.618) % 1.0) * 0.6);
      final d = (sa - ba) % (2 * math.pi);
      final al = math.max(0.0, 1 - d / (math.pi * 1.2));
      if (al > 0) {
        _c.drawCircle(p(br, ba), r * 0.028, glow(Paint()..color = acc.withOpacity(al), 4));
        _c.drawCircle(p(br, ba), r * 0.012, Paint()..color = Colors.white.withOpacity(al));
      }
    }
    final rect = Rect.fromCircle(center: c, radius: r * 0.98);
    _c.drawArc(rect, a0, sw, false, stroke(6, Colors.white.withOpacity(0.06)));
    if (f > 0.002) _c.drawArc(rect, a0, sw * f, false, stroke(6, acc));
    _c.drawCircle(c, r * 0.34, Paint()..color = Colors.black.withOpacity(0.65));
    _c.drawCircle(c, r * 0.34, stroke(2, acc.withOpacity(0.6)));
    number(scale: 0.34, w: FontWeight.w800);
  }

  // ---------------------------------------------------------------- zen
  void _zen() {
    final br = 0.5 + 0.5 * math.sin(t * 1.6);
    _c.drawCircle(
        c,
        r * 0.85,
        Paint()
          ..shader = RadialGradient(colors: [acc.withOpacity(0.10 + 0.05 * br), Colors.transparent])
              .createShader(Rect.fromCircle(center: c, radius: r * 0.85)));
    text('${k.v.round()}', c - Offset(0, r * 0.1), r * 0.8, warn ? acc : Colors.white, w: FontWeight.w100);
    final y = c.dy + r * 0.5;
    final len = r * 1.6;
    final x0 = c.dx - len / 2;
    _c.drawLine(Offset(x0, y), Offset(x0 + len, y), stroke(3, Colors.white.withOpacity(0.12)));
    final step = cfg.max > 160 ? 20 : 10;
    for (var v = 0; v <= cfg.max; v += step) {
      final x = x0 + len * v / cfg.max;
      _c.drawLine(Offset(x, y - r * 0.03), Offset(x, y - r * 0.06), stroke(1.5, Colors.white.withOpacity(0.3)));
    }
    _c.drawLine(Offset(x0, y), Offset(x0 + len * f, y), glow(stroke(6, acc.withOpacity(0.5)), 5));
    _c.drawLine(Offset(x0, y), Offset(x0 + len * f, y), stroke(3, acc));
    _c.drawCircle(Offset(x0 + len * f, y), r * 0.03, Paint()..color = Colors.white);
    text(cfg.unit, Offset(c.dx, y + r * 0.14), r * 0.08, acc, spacing: 6);
  }

  // ---------------------------------------------------------------- tunnel
  void _tunnel() {
    _c.save();
    _c.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.97)));
    _c.drawCircle(c, r, Paint()..color = Colors.black.withOpacity(0.35));
    const n = 14;
    final speed = 0.08 + f * 1.4;
    final rot = t * 0.15;
    for (var j = 0; j < n; j++) {
      final z = ((j / n) + t * speed) % 1.0;
      final s = z * z;
      _c.drawPath(poly(6, r * 1.25 * s, rot), stroke(1 + 4 * s, Color.lerp(cfg.base, acc, z)!.withOpacity(z * 0.9), round: false));
    }
    for (var q = 0; q < 6; q++) {
      _c.drawLine(c, p(r, rot + q * math.pi / 3), stroke(1, acc.withOpacity(0.15)));
    }
    _c.restore();
    _c.drawCircle(c, r * 0.97, stroke(2.5, acc.withOpacity(0.7)));
    final rect = Rect.fromCircle(center: c, radius: r * 0.97);
    if (f > 0.002) {
      _c.drawArc(rect, a0, sw * f, false, glow(stroke(12, acc.withOpacity(0.4)), 8));
      _c.drawArc(rect, a0, sw * f, false, stroke(6, acc));
    }
    _c.drawCircle(c, r * 0.3, Paint()..color = Colors.black.withOpacity(0.75));
    number(scale: 0.32, w: FontWeight.w800);
  }

  @override
  bool shouldRepaint(covariant GaugePainter o) => true;
}

// ================================================================ background fx
class FxPainter extends CustomPainter {
  final DashClock k;
  final String fx;
  final GaugeCfg cfg;
  FxPainter(this.k, this.fx, this.cfg) : super(repaint: k);

  @override
  void paint(Canvas canvas, Size size) {
    final t = k.t;
    final f = (k.v / cfg.max).clamp(0.0, 1.0).toDouble();
    final acc = cfg.accent;
    final ctr = size.center(Offset.zero);
    switch (fx) {
      case 'warp':
        final maxR = size.longestSide * 0.6;
        for (var i = 0; i < 140; i++) {
          final ang = (i * 2.39996) % (2 * math.pi);
          final b0 = (i * 0.618034) % 1.0;
          final d = (b0 + t * (0.03 + f * 0.6)) % 1.0;
          final dir = Offset(math.cos(ang), math.sin(ang));
          final rr = d * d * maxR;
          final len = maxR * (0.004 + f * 0.09) * d;
          canvas.drawLine(
              ctr + dir * rr,
              ctr + dir * (rr + len),
              Paint()
                ..color = Color.lerp(Colors.white, acc, (i % 5) / 5)!.withOpacity(0.06 + 0.5 * d)
                ..strokeWidth = 1 + 1.6 * d
                ..strokeCap = StrokeCap.round);
        }
      case 'flow':
        for (var i = 0; i < 22; i++) {
          final y = size.height * (i + 0.5) / 22;
          final rnd = (i * 0.7548) % 1.0;
          final len = 60 + f * 380 + rnd * 80;
          final total = size.width + len;
          final x = size.width - ((t * (30 + k.v * 9) * (0.6 + rnd) + rnd * total) % total);
          final rect = Rect.fromLTWH(x, y - 1, len, 2);
          canvas.drawRect(
              rect,
              Paint()
                ..shader = LinearGradient(colors: [acc.withOpacity(0.25 + 0.2 * rnd), acc.withOpacity(0)]).createShader(rect));
        }
      case 'aurora':
        for (var i = 0; i < 3; i++) {
          final o = Offset(
            size.width * (0.5 + 0.35 * math.sin(t * (0.08 + f * 0.3) * (i + 1) + i * 2)),
            size.height * (0.5 + 0.3 * math.cos(t * (0.06 + f * 0.25) * (i + 1) + i)),
          );
          final rad = size.shortestSide * (0.5 + 0.12 * i);
          canvas.drawCircle(
              o,
              rad,
              Paint()
                ..shader = RadialGradient(colors: [(i == 1 ? cfg.base : acc).withOpacity(0.16), Colors.transparent])
                    .createShader(Rect.fromCircle(center: o, radius: rad)));
        }
      case 'dots':
        const gap = 52.0;
        for (var x = gap / 2; x < size.width; x += gap) {
          for (var y = gap / 2; y < size.height; y += gap) {
            final d = (Offset(x, y) - ctr).distance;
            final w = (math.sin(d * 0.025 - t * (1.2 + f * 7)) + 1) / 2;
            canvas.drawCircle(Offset(x, y), 1.4 + 1.6 * w, Paint()..color = acc.withOpacity(0.05 + 0.15 * w));
          }
        }
    }
  }

  @override
  bool shouldRepaint(covariant FxPainter o) => true;
}

// ================================================================ tiles
class _Tiles {
  final Color accent;
  final String style;
  final bool mph;
  const _Tiles({required this.accent, required this.style, required this.mph});

  Map<String, String> _values() {
    final g = Gps.instance;
    final st = Settings.instance;
    final f = mph ? 0.621371 : 1.0;
    final unit = mph ? 'mph' : 'كم/س';
    String dur(Duration d) =>
        '${d.inHours > 0 ? '${d.inHours}:' : ''}${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    final next = Prayer.instance.next;
    return {
      'trip': mph ? '${(g.distanceKm * f).toStringAsFixed(1)} mi' : '${g.distanceKm.toStringAsFixed(1)} كم',
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
  }

  Widget grid(List<String> ids, int cols) {
    return ListenableBuilder(
      listenable: Gps.instance,
      builder: (context, _) {
        final values = _values();
        final rows = <Widget>[];
        for (var i = 0; i < ids.length; i += cols) {
          rows.add(Expanded(
            child: Row(children: [
              for (var j = i; j < i + cols; j++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: j < ids.length ? _tile(ids[j], values[ids[j]] ?? '—') : const SizedBox(),
                  ),
                ),
            ]),
          ));
        }
        return Column(children: rows);
      },
    );
  }

  Widget _tile(String id, String value) {
    final meta = carTilesAll.firstWhere((e) => e.$1 == id);
    final content = Row(children: [
      Icon(meta.$3, color: accent, size: 30),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(value,
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
              ),
            ),
            Text(meta.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: AppColors.muted)),
          ],
        ),
      ),
    ]);
    const pad = EdgeInsets.symmetric(horizontal: 14, vertical: 8);
    final tile = switch (style) {
      'line' => Container(
          padding: pad,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withOpacity(0.75), width: 1.5),
            gradient: LinearGradient(colors: [accent.withOpacity(0.14), Colors.transparent]),
            boxShadow: [BoxShadow(color: accent.withOpacity(0.18), blurRadius: 16)],
          ),
          child: content,
        ),
      'bare' => Container(
          padding: pad,
          decoration: BoxDecoration(
            border: BorderDirectional(start: BorderSide(color: accent, width: 4)),
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [Colors.white.withOpacity(0.06), Colors.transparent],
            ),
          ),
          child: content,
        ),
      _ => Glass(blur: false, radius: 20, padding: pad, child: content),
    };
    if (id == 'trip' || id == 'time' || id == 'max' || id == 'avg' || id == 'z100') {
      return GestureDetector(onLongPress: Gps.instance.resetTrip, child: tile);
    }
    return tile;
  }
}

// ================================================================ mini player
class _MiniPlayer extends StatelessWidget {
  final Widget Function(Widget) swap;
  final VoidCallback next;
  final VoidCallback prev;
  final Color accent;
  const _MiniPlayer({required this.swap, required this.next, required this.prev, required this.accent});

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
            child: swap(Column(
              key: ValueKey(p.title),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.hasMedia ? p.title : 'اضغط تشغيل',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                Text(p.hasMedia ? p.subtitle : '',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, color: accent)),
              ],
            )),
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

// ================================================================ gauge thumbnail
/// Small self-animating gauge used to pick a style.
class GaugePreview extends StatefulWidget {
  final String style;
  final Color accent;
  final double phase;
  const GaugePreview({super.key, required this.style, required this.accent, this.phase = 0});

  @override
  State<GaugePreview> createState() => _GaugePreviewState();
}

class _GaugePreviewState extends State<GaugePreview> with SingleTickerProviderStateMixin {
  final _clock = DashClock();
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _clock.t = widget.phase;
    _ticker = createTicker((e) {
      final dt = ((e - _last).inMicroseconds / 1e6).clamp(0.0, 0.1).toDouble();
      _last = e;
      _clock.step(dt, _demoSpeed(_clock.t, 220));
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: GaugePainter(
          _clock,
          GaugeCfg(style: widget.style, max: 220, accent: widget.accent, base: AppColors.emerald, unit: 'كم/س'),
        ),
      ),
    );
  }
}

// ================================================================ customiser
/// Every piece of the speedometer style can be mixed & matched here.
class CarDashCustomizer extends StatelessWidget {
  const CarDashCustomizer({super.key});

  Widget _h(String t, [String? sub]) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 12),
        child: Row(children: [
          Text(t, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.gold)),
          if (sub != null) ...[
            const SizedBox(width: 10),
            Flexible(child: Text(sub, style: TextStyle(fontSize: 15, color: AppColors.muted), overflow: TextOverflow.ellipsis)),
          ],
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final st = Settings.instance;
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final tiles = st.carTiles;
        final acc = carAccentColor();
        final gaugeName = carGauges.firstWhere((g) => g.$1 == st.carGauge).$2;
        return SectionCard(
          icon: Icons.speed_rounded,
          title: 'تخصيص عداد السرعة',
          subtitle: 'الثيم الوحيد اللي كل حتة فيه ليها أكتر من شكل — ركّب على مزاجك والمعاينة بتتغير قدامك',
          trailing: GlassButton(
            icon: Icons.fullscreen_rounded,
            label: 'افتحه',
            size: 48,
            primary: true,
            onTap: () => DriveMode.open(context, style: 'car'),
          ),
          children: [
            // ---------------------------------------------- live preview
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 380,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black, AppColors.bg0],
                  ),
                  border: Border.all(color: acc.withOpacity(0.5), width: 1.5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(children: [
                  Positioned.fill(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 1500,
                        height: 700,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: IgnorePointer(
                            child: CarDashBody(preview: true, swap: (w) => w, next: () {}, prev: () {}),
                          ),
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: 12,
                    start: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(14)),
                      child: Text('معاينة حية — سرعة تجريبية', style: TextStyle(fontSize: 14, color: acc)),
                    ),
                  ),
                ]),
              ),
            ),

            // ---------------------------------------------- gauge style
            _h('شكل العداد', 'المختار: $gaugeName'),
            Wrap(spacing: 14, runSpacing: 14, children: [
              for (var i = 0; i < carGauges.length; i++)
                _GaugeCard(
                  id: carGauges[i].$1,
                  name: carGauges[i].$2,
                  desc: carGauges[i].$3,
                  accent: acc,
                  phase: i * 3.7,
                  selected: st.carGauge == carGauges[i].$1,
                  onTap: () => st.setOpt('carGauge', carGauges[i].$1),
                ),
            ]),

            // ---------------------------------------------- accent
            _h('لون الإضاءة', 'المختار: ${carAccents.firstWhere((a) => a.$1 == st.carAccent, orElse: () => carAccents.first).$2}'),
            Wrap(spacing: 14, runSpacing: 14, children: [
              for (final (col, name) in carAccents)
                _Swatch(
                  color: col == 0 ? AppColors.gold : Color(col),
                  name: name,
                  theme: col == 0,
                  selected: st.carAccent == col,
                  onTap: () => st.setOpt('carAccent', col),
                ),
            ]),

            // ---------------------------------------------- fx / layout / tile style
            _h('الخلفية المتحركة', 'بتسرع مع سرعتك الحقيقية'),
            ChoiceRow<String>(options: carFxs, value: st.carFx, onChanged: (v) => st.setOpt('carFx', v)),
            _h('ترتيب الشاشة'),
            ChoiceRow<String>(options: carLayouts, value: st.carLayout, onChanged: (v) => st.setOpt('carLayout', v)),
            _h('شكل الخانات'),
            ChoiceRow<String>(options: carTileStyles, value: st.carTileStyle, onChanged: (v) => st.setOpt('carTileStyle', v)),

            // ---------------------------------------------- tiles
            _h('البيانات اللي تظهر', 'مختار ${tiles.length} من 6'),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final (id, label, icon) in carTilesAll)
                _TileChip(
                  label: label,
                  icon: icon,
                  order: tiles.contains(id) ? tiles.indexOf(id) + 1 : 0,
                  onTap: () {
                    final l = [...tiles];
                    if (l.contains(id)) {
                      l.remove(id);
                    } else {
                      if (l.length >= 6) l.removeAt(0);
                      l.add(id);
                    }
                    st.setOpt('carTiles', l);
                  },
                ),
            ]),

            // ---------------------------------------------- units & extras
            _h('الوحدة وأقصى رقم'),
            ChoiceRow<bool>(options: const [(false, 'كم/س'), (true, 'ميل/س')], value: st.carMph, onChanged: (v) => st.setOpt('carMph', v)),
            const SizedBox(height: 10),
            ChoiceRow<int>(
              options: const [(140, '140'), (180, '180'), (220, '220'), (260, '260')],
              value: st.carMax,
              onChanged: (v) => st.setOpt('carMax', v),
            ),
            const SizedBox(height: 8),
            SliderRow(
              title: 'تنبيه تخطي السرعة',
              value: st.carLimit.toDouble(),
              min: 0,
              max: 180,
              divisions: 18,
              label: (v) => v == 0 ? 'مقفول' : '${v.round()} كم/س',
              onChanged: (v) => st.setOpt('carLimit', v.round()),
            ),
            ToggleRow(
              title: 'مشغّل القرآن تحت العداد',
              value: st.carPlayer,
              onChanged: (v) => st.setOpt('carPlayer', v),
            ),
            ToggleRow(
              title: 'وضع العرض (سرعة تجريبية)',
              subtitle: 'تشوف العداد بيتحرك وانت راكن — اقفله وانت سايق عشان يقرا الـ GPS',
              value: st.carDemo,
              onChanged: (v) => st.setOpt('carDemo', v),
            ),
            const SizedBox(height: 8),
            Row(children: [
              GlassButton(icon: Icons.restart_alt_rounded, label: 'صفّر المشوار', size: 48, onTap: Gps.instance.resetTrip),
              const SizedBox(width: 12),
              Expanded(
                child: Text('ضغطة طويلة على أي خانة من خانات المشوار جوه العداد بتصفّرها برضه',
                    style: TextStyle(fontSize: 15, color: AppColors.muted)),
              ),
            ]),
          ],
        );
      },
    );
  }
}

class _GaugeCard extends StatelessWidget {
  final String id, name, desc;
  final Color accent;
  final double phase;
  final bool selected;
  final VoidCallback onTap;
  const _GaugeCard({
    required this.id,
    required this.name,
    required this.desc,
    required this.accent,
    required this.phase,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.95,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          width: 210,
          height: 262,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: selected ? AppColors.gold.withOpacity(0.16) : Colors.black.withOpacity(0.35),
            border: Border.all(color: selected ? AppColors.gold : Colors.white12, width: selected ? 3 : 1),
            boxShadow: selected ? [BoxShadow(color: AppColors.gold.withOpacity(0.4), blurRadius: 24)] : null,
          ),
          child: Stack(children: [
            Column(children: [
              Expanded(child: GaugePreview(style: id, accent: accent, phase: phase)),
              const SizedBox(height: 6),
              Text(name,
                  style: TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w900, color: selected ? AppColors.gold : AppColors.text)),
              Text(desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: AppColors.muted)),
            ]),
            if (selected)
              PositionedDirectional(
                top: 0,
                start: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.gold),
                  child: Icon(Icons.check_rounded, size: 22, color: AppColors.bg0),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final String name;
  final bool theme;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch({required this.color, required this.name, required this.theme, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: selected ? 64 : 54,
          height: selected ? 64 : 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: selected ? Colors.white : Colors.white24, width: selected ? 4 : 1.5),
            boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.7), blurRadius: 20)] : null,
          ),
          child: selected
              ? const Icon(Icons.check_rounded, color: Colors.black, size: 30)
              : (theme ? const Icon(Icons.palette_outlined, color: Colors.black54, size: 24) : null),
        ),
        const SizedBox(height: 6),
        Text(name,
            style: TextStyle(
                fontSize: 14, fontWeight: selected ? FontWeight.w900 : FontWeight.w500, color: selected ? AppColors.text : AppColors.muted)),
      ]),
    );
  }
}

class _TileChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final int order; // 0 = not selected, else position on screen
  final VoidCallback onTap;
  const _TileChip({required this.label, required this.icon, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final on = order > 0;
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: on ? AppColors.gold : Colors.white.withOpacity(0.05),
          border: Border.all(color: on ? AppColors.gold : Colors.white24, width: on ? 2 : 1),
          boxShadow: on ? [BoxShadow(color: AppColors.gold.withOpacity(0.3), blurRadius: 12)] : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (on)
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.bg0),
              child: Text('$order', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.gold)),
            )
          else
            Icon(icon, size: 22, color: AppColors.gold),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 16, fontWeight: on ? FontWeight.w900 : FontWeight.w500, color: on ? AppColors.bg0 : AppColors.text)),
        ]),
      ),
    );
  }
}
