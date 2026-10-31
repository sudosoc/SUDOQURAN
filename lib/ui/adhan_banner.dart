import 'package:flutter/material.dart';

import '../services/player.dart';
import '../services/prayer.dart';
import 'glass.dart';

/// Slides down from the top at adhan time.
class AdhanBanner extends StatelessWidget {
  const AdhanBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: Prayer.instance.banner,
      builder: (context, text, _) => AnimatedPositioned(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutBack,
        top: text == null ? -160 : 24,
        left: 0,
        right: 0,
        child: Center(
          child: Glass(
            radius: 40,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            borderColor: AppColors.gold,
            borderWidth: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mosque_rounded, color: AppColors.gold, size: 44),
                const SizedBox(width: 16),
                Text(text ?? '', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(width: 22),
                GlassButton(
                  icon: Icons.close_rounded,
                  label: 'إيقاف',
                  size: 56,
                  onTap: () {
                    Prayer.instance.banner.value = null;
                    Player.instance.stopInterrupt();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
