import 'package:flutter/material.dart';

import '../services/settings.dart';
import 'car_dash.dart';
import 'drive_mode.dart';
import 'glass.dart';
import 'settings_widgets.dart';

class DriveTab extends StatelessWidget {
  const DriveTab({super.key});

  @override
  Widget build(BuildContext context) {
    final st = Settings.instance;
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SectionCard(
              icon: Icons.directions_car_rounded,
              title: 'شكل وضع السواقة',
              subtitle: 'اختار الشكل اللي يريحك — "جرّب" بيفتحه على طول',
              children: [
                ToggleRow(
                  title: 'افتح على وضع السواقة',
                  subtitle: 'أول ما التطبيق يفتح يدخل عليه على طول',
                  value: st.driveOnLaunch,
                  onChanged: st.setDriveOnLaunch,
                ),
              ],
            ),
          ),
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 210,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final d = driveStyles[i];
                final sel = st.driveStyle == d.id;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: () => st.setOpt('driveStyle', d.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        color: sel ? AppColors.gold.withOpacity(0.14) : Colors.white.withOpacity(0.05),
                        border: Border.all(color: sel ? AppColors.gold : Colors.white24, width: sel ? 2.5 : 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: [AppColors.gold, AppColors.emerald]),
                              ),
                              child: Icon(d.icon, color: AppColors.bg0, size: 32),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(d.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                            ),
                            if (sel) Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 30),
                          ]),
                          const SizedBox(height: 10),
                          Text(d.desc, maxLines: 2, style: TextStyle(fontSize: 16, color: AppColors.muted)),
                          const Spacer(),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: GlassButton(
                              icon: Icons.visibility_rounded,
                              label: 'جرّب',
                              size: 48,
                              onTap: () => DriveMode.open(context, style: d.id),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              childCount: driveStyles.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(child: CarDashCustomizer()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

