import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/library.dart';

class AppThemeData {
  final String id;
  final String name;
  final Color bg0, bg1, bg2, gold, emerald, teal;
  const AppThemeData(this.id, this.name,
      {required this.bg0,
      required this.bg1,
      required this.bg2,
      required this.gold,
      required this.emerald,
      required this.teal});
}

AppThemeData _t(String id, String name, int bg0, int bg1, int bg2, int gold, int emerald, int teal) =>
    AppThemeData(id, name,
        bg0: Color(bg0), bg1: Color(bg1), bg2: Color(bg2),
        gold: Color(gold), emerald: Color(emerald), teal: Color(teal));

final appThemes = <AppThemeData>[
  _t('emerald', 'زمرد وذهب', 0xFF040F15, 0xFF082630, 0xFF0F1B33, 0xFFE6C27A, 0xFF3DDC97, 0xFF2BB3C0),
  _t('crimson', 'أسود ملكي أحمر', 0xFF000000, 0xFF1A0507, 0xFF121212, 0xFFE5484D, 0xFF9B111E, 0xFF3A3A3A),
  _t('amoled', 'أسود AMOLED', 0xFF000000, 0xFF0A0A0A, 0xFF050505, 0xFFE6C27A, 0xFF3DDC97, 0xFF555555),
  _t('graphite', 'جرافيت', 0xFF0B0B0D, 0xFF1C1D21, 0xFF141518, 0xFFD9DCE1, 0xFF8A8F98, 0xFF4B5058),
  _t('midnight', 'ليل أزرق', 0xFF050814, 0xFF0D1838, 0xFF1A1036, 0xFFBFD4FF, 0xFF5B8CFF, 0xFF8B5CF6),
  _t('royal', 'بنفسجي ملكي', 0xFF0A0614, 0xFF1D0F36, 0xFF120A24, 0xFFE9C46A, 0xFF9D4EDD, 0xFF5A189A),
  _t('ocean', 'محيط', 0xFF020C14, 0xFF06283D, 0xFF0A1A2F, 0xFF9AE6F5, 0xFF1FB6D4, 0xFF256D85),
  _t('desert', 'صحراء', 0xFF140C06, 0xFF2E1D0E, 0xFF241510, 0xFFF2C38B, 0xFFE8945A, 0xFFC96F4A),
  _t('copper', 'نحاسي', 0xFF0E0806, 0xFF2A140C, 0xFF1A0E0A, 0xFFF0A868, 0xFFB86B3C, 0xFF6E3B22),
  _t('forest', 'غابة', 0xFF040D07, 0xFF0C2414, 0xFF13261A, 0xFFD9E8A0, 0xFF7BD389, 0xFF3FA36B),
  _t('olive', 'زيتوني', 0xFF0A0B05, 0xFF1F230F, 0xFF16180C, 0xFFE3D58C, 0xFFA3B14B, 0xFF5E6B2A),
  _t('rose', 'وردي هادي', 0xFF12070C, 0xFF2A0F1E, 0xFF1C0D24, 0xFFF5C6D6, 0xFFEC6F9B, 0xFFB66DFF),
  _t('sunset', 'غروب', 0xFF120509, 0xFF2D0B1A, 0xFF1F0A0A, 0xFFFFC371, 0xFFFF5F6D, 0xFFB23A48),
  _t('ice', 'ثلجي داكن', 0xFF060A0F, 0xFF121C26, 0xFF0C131B, 0xFFE8F1F8, 0xFF7FB3D5, 0xFF41658A),
];

/// Built from the user's own colours (Settings → الثيمات → ثيم مخصص).
AppThemeData customTheme(List<int> c) => AppThemeData('custom', 'ثيم مخصص',
    bg0: Color(c[0]),
    bg1: Color(c[1]),
    bg2: Color.lerp(Color(c[0]), Color(c[1]), 0.5)!,
    gold: Color(c[2]),
    emerald: Color(c[3]),
    teal: Color.lerp(Color(c[3]), Color(c[1]), 0.4)!);

AppThemeData themeById(String? id, [List<int>? custom]) {
  if (id == 'custom' && custom != null && custom.length >= 4) return customTheme(custom);
  return appThemes.firstWhere((t) => t.id == id, orElse: () => appThemes.first);
}

/// Live palette — values change when the user picks another theme.
class AppColors {
  static String themeId = 'emerald';
  static Color bg0 = const Color(0xFF040F15);
  static Color bg1 = const Color(0xFF082630);
  static Color bg2 = const Color(0xFF0F1B33);
  static Color gold = const Color(0xFFE6C27A);
  static Color emerald = const Color(0xFF3DDC97);
  static Color teal = const Color(0xFF2BB3C0);
  static Color text = const Color(0xFFF4F1EA);
  static Color muted = const Color(0xB3F4F1EA);

  static void apply(AppThemeData t) {
    themeId = t.id;
    bg0 = t.bg0;
    bg1 = t.bg1;
    bg2 = t.bg2;
    gold = t.gold;
    emerald = t.emerald;
    teal = t.teal;
  }
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.emerald,
      brightness: Brightness.dark,
      primary: AppColors.emerald,
      secondary: AppColors.gold,
      surface: AppColors.bg1,
    ),
    scaffoldBackgroundColor: AppColors.bg0,
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
      fontSizeFactor: 1.12,
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 6,
      activeTrackColor: AppColors.gold,
      inactiveTrackColor: Color(0x33FFFFFF),
      thumbColor: AppColors.gold,
      overlayColor: Color(0x22E6C27A),
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xEE10303A),
      contentTextStyle: TextStyle(fontSize: 18, color: AppColors.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

/// Frosted glass panel. Set [blur] to false for small repeated tiles
/// (cheaper on the head unit GPU — they still look glassy over the panel).
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool blur;
  final double opacity;
  final Color? borderColor;
  final double borderWidth;

  const Glass({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = const EdgeInsets.all(20),
    this.blur = true,
    this.opacity = 0.10,
    this.borderColor,
    this.borderWidth = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(opacity + 0.06),
            Colors.white.withOpacity(opacity * 0.4),
          ],
        ),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.16),
          width: borderWidth,
        ),
      ),
      child: child,
    );
    if (!blur) {
      return ClipRRect(borderRadius: BorderRadius.circular(radius), child: body);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: body,
      ),
    );
  }
}

/// Big touch-friendly glass button (≥ 64dp) for use while driving.
class GlassButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  final double size;
  final bool primary;
  final Color? color;

  const GlassButton({
    super.key,
    required this.icon,
    this.label,
    this.onTap,
    this.size = 64,
    this.primary = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fg = onTap == null
        ? Colors.white24
        : (primary ? AppColors.bg0 : (color ?? AppColors.text));
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(size),
      gradient: primary
          ? LinearGradient(
              colors: [AppColors.gold, Color(0xFFF3DDA6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight)
          : null,
      color: primary ? null : Colors.white.withOpacity(0.08),
      border: Border.all(color: Colors.white.withOpacity(primary ? 0.0 : 0.16)),
      boxShadow: primary
          ? [BoxShadow(color: AppColors.gold.withOpacity(0.35), blurRadius: 28)]
          : null,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(size),
        onTap: onTap,
        child: Ink(
          decoration: decoration,
          height: size,
          padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 22),
          width: label == null ? size : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: size * 0.48),
              if (label != null) ...[
                const SizedBox(width: 10),
                Text(label!,
                    style: TextStyle(
                        color: fg, fontSize: 19, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Deep gradient + glowing orbs + faint Islamic star pattern.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: CustomPaint(painter: _BgPainter(), size: Size.infinite),
    );
  }
}

class _BgPainter extends CustomPainter {
  const _BgPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.bg1, AppColors.bg0, AppColors.bg2],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );

    void orb(Offset c, double r, Color color) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            color.withOpacity(0.55),
            color.withOpacity(0.0),
          ]).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    orb(Offset(size.width * 0.82, size.height * 0.12), size.height * 0.55,
        AppColors.emerald);
    orb(Offset(size.width * 0.18, size.height * 0.85), size.height * 0.6,
        AppColors.gold);
    orb(Offset(size.width * 0.45, size.height * 0.45), size.height * 0.45,
        AppColors.teal);

    // eight-pointed star lattice
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withOpacity(0.035);
    const step = 110.0;
    const r = 30.0;
    for (var y = step / 2; y < size.height + step; y += step) {
      for (var x = step / 2; x < size.width + step; x += step) {
        for (final rot in [0.0, math.pi / 4]) {
          final path = Path();
          for (var i = 0; i < 4; i++) {
            final a = rot + i * math.pi / 2 + math.pi / 4;
            final pt = Offset(x + r * math.cos(a), y + r * math.sin(a));
            i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
          }
          path.close();
          canvas.drawPath(path, p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Gold-ringed disc: the photo the user chose for that sheikh, otherwise a
/// painted mushaf (open Quran) on the theme colours.
class ReciterAvatar extends StatelessWidget {
  final String letters; // kept for API compatibility
  final String? photoId;
  final double size;
  final bool glow;
  const ReciterAvatar(this.letters, {super.key, this.photoId, this.size = 64, this.glow = false});

  @override
  Widget build(BuildContext context) {
    final photo = photoId == null ? null : Library.instance.photoFor(photoId!);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(AppColors.bg1, AppColors.emerald, 0.35)!, AppColors.bg0],
        ),
        image: photo == null ? null : DecorationImage(image: FileImage(photo), fit: BoxFit.cover),
        border: Border.all(color: AppColors.gold.withOpacity(0.8), width: size / 28),
        boxShadow: glow
            ? [BoxShadow(color: AppColors.emerald.withOpacity(0.45), blurRadius: size / 3)]
            : [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: size / 8, offset: Offset(0, size / 20))],
      ),
      child: photo != null
          ? null
          : Padding(
              padding: EdgeInsets.all(size * 0.17),
              child: CustomPaint(painter: MushafPainter(AppColors.gold, AppColors.bg0)),
            ),
    );
  }
}

/// An open mushaf on a stand with an eight-pointed star above it.
class MushafPainter extends CustomPainter {
  final Color gold;
  final Color ink;
  const MushafPainter(this.gold, this.ink);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final fill = Paint()..color = gold;
    final page = Paint()..color = gold.withOpacity(0.92);
    final line = Paint()
      ..color = ink.withOpacity(0.55)
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round;

    // star
    final c = Offset(w / 2, h * 0.16);
    final r = w * 0.13;
    for (final rot in [0.0, math.pi / 4]) {
      final p = Path();
      for (var i = 0; i < 4; i++) {
        final a = rot + i * math.pi / 2 + math.pi / 4;
        final pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(p..close(), fill);
    }
    canvas.drawCircle(c, r * 0.38, Paint()..color = ink.withOpacity(0.6));

    // two pages
    final top = h * 0.36, bottom = h * 0.80, mid = w / 2;
    Path pageL = Path()
      ..moveTo(mid, top + h * 0.06)
      ..quadraticBezierTo(w * 0.28, top - h * 0.03, w * 0.04, top + h * 0.02)
      ..lineTo(w * 0.04, bottom - h * 0.02)
      ..quadraticBezierTo(w * 0.28, bottom - h * 0.07, mid, bottom)
      ..close();
    Path pageR = Path()
      ..moveTo(mid, top + h * 0.06)
      ..quadraticBezierTo(w * 0.72, top - h * 0.03, w * 0.96, top + h * 0.02)
      ..lineTo(w * 0.96, bottom - h * 0.02)
      ..quadraticBezierTo(w * 0.72, bottom - h * 0.07, mid, bottom)
      ..close();
    canvas.drawPath(pageL, page);
    canvas.drawPath(pageR, page);
    // text lines
    for (var i = 0; i < 4; i++) {
      final y = top + h * 0.11 + i * h * 0.085;
      canvas.drawLine(Offset(w * 0.12, y), Offset(mid - w * 0.07, y + h * 0.012), line);
      canvas.drawLine(Offset(mid + w * 0.07, y + h * 0.012), Offset(w * 0.88, y), line);
    }
    // spine + stand (rahl)
    canvas.drawLine(Offset(mid, top + h * 0.06), Offset(mid, bottom), line..strokeWidth = w * 0.03);
    final stand = Paint()
      ..color = gold
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.18, h * 0.97), Offset(w * 0.82, bottom + h * 0.05), stand);
    canvas.drawLine(Offset(w * 0.82, h * 0.97), Offset(w * 0.18, bottom + h * 0.05), stand);
  }

  @override
  bool shouldRepaint(covariant MushafPainter old) => old.gold != gold || old.ink != ink;
}

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
}
