import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class AppColors {
  static const bg0 = Color(0xFF040F15);
  static const bg1 = Color(0xFF082630);
  static const bg2 = Color(0xFF0F1B33);
  static const gold = Color(0xFFE6C27A);
  static const emerald = Color(0xFF3DDC97);
  static const teal = Color(0xFF2BB3C0);
  static const text = Color(0xFFF4F1EA);
  static const muted = Color(0xB3F4F1EA);
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
    sliderTheme: const SliderThemeData(
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
      contentTextStyle: const TextStyle(fontSize: 18, color: AppColors.text),
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
          ? const LinearGradient(
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
        ..shader = const LinearGradient(
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

/// Gold-ringed disc showing a reciter's initials.
class ReciterAvatar extends StatelessWidget {
  final String letters;
  final double size;
  final bool glow;
  const ReciterAvatar(this.letters, {super.key, this.size = 64, this.glow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E5B5E), Color(0xFF0B2A3A)],
        ),
        border: Border.all(color: AppColors.gold.withOpacity(0.7), width: size / 28),
        boxShadow: glow
            ? [BoxShadow(color: AppColors.emerald.withOpacity(0.35), blurRadius: size / 3)]
            : null,
      ),
      child: Text(
        letters,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.gold,
          fontSize: size * (letters.length > 3 ? 0.24 : 0.32),
          fontWeight: FontWeight.w700,
          height: 1.1,
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
