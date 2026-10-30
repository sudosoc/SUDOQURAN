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

const appThemes = <AppThemeData>[
  AppThemeData('emerald', 'زمرد وذهب',
      bg0: Color(0xFF040F15), bg1: Color(0xFF082630), bg2: Color(0xFF0F1B33),
      gold: Color(0xFFE6C27A), emerald: Color(0xFF3DDC97), teal: Color(0xFF2BB3C0)),
  AppThemeData('midnight', 'ليل أزرق',
      bg0: Color(0xFF050814), bg1: Color(0xFF0D1838), bg2: Color(0xFF1A1036),
      gold: Color(0xFFBFD4FF), emerald: Color(0xFF5B8CFF), teal: Color(0xFF8B5CF6)),
  AppThemeData('desert', 'صحراء',
      bg0: Color(0xFF140C06), bg1: Color(0xFF2E1D0E), bg2: Color(0xFF241510),
      gold: Color(0xFFF2C38B), emerald: Color(0xFFE8945A), teal: Color(0xFFC96F4A)),
  AppThemeData('rose', 'وردي هادي',
      bg0: Color(0xFF12070C), bg1: Color(0xFF2A0F1E), bg2: Color(0xFF1C0D24),
      gold: Color(0xFFF5C6D6), emerald: Color(0xFFEC6F9B), teal: Color(0xFFB66DFF)),
  AppThemeData('forest', 'غابة',
      bg0: Color(0xFF040D07), bg1: Color(0xFF0C2414), bg2: Color(0xFF13261A),
      gold: Color(0xFFD9E8A0), emerald: Color(0xFF7BD389), teal: Color(0xFF3FA36B)),
  AppThemeData('amoled', 'أسود (AMOLED)',
      bg0: Color(0xFF000000), bg1: Color(0xFF0A0A0A), bg2: Color(0xFF050505),
      gold: Color(0xFFE6C27A), emerald: Color(0xFF3DDC97), teal: Color(0xFF555555)),
];

AppThemeData themeById(String? id) =>
    appThemes.firstWhere((t) => t.id == id, orElse: () => appThemes.first);

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

/// Gold-ringed disc: the reciter's photo if the user set one, otherwise
/// calligraphic initials on a colour unique to that reciter.
class ReciterAvatar extends StatelessWidget {
  final String letters;
  final String? photoId;
  final double size;
  final bool glow;
  const ReciterAvatar(this.letters, {super.key, this.photoId, this.size = 64, this.glow = false});

  @override
  Widget build(BuildContext context) {
    final photo = photoId == null ? null : Library.instance.photoFor(photoId!);
    final hue = ((photoId ?? letters).codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0xFFFF) % 360).toDouble();
    final c1 = HSLColor.fromAHSL(1, hue, 0.45, 0.30).toColor();
    final c2 = HSLColor.fromAHSL(1, (hue + 40) % 360, 0.55, 0.14).toColor();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2],
        ),
        image: photo == null
            ? null
            : DecorationImage(image: FileImage(photo), fit: BoxFit.cover),
        border: Border.all(color: AppColors.gold.withOpacity(0.75), width: size / 28),
        boxShadow: glow
            ? [BoxShadow(color: AppColors.emerald.withOpacity(0.4), blurRadius: size / 3)]
            : [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: size / 8, offset: Offset(0, size / 20))],
      ),
      child: photo != null
          ? null
          : Text(
              letters,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.gold,
                fontSize: size * (letters.length > 3 ? 0.24 : 0.34),
                fontWeight: FontWeight.w800,
                height: 1.1,
                shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
              ),
            ),
    );
  }
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
