import 'package:flutter/material.dart';

import '../services/gps.dart';
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


/// Every piece of the speedometer style can be mixed & matched here.
class CarDashCustomizer extends StatelessWidget {
  const CarDashCustomizer({super.key});

  Widget _h(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Text(t, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.gold)),
      );

  @override
  Widget build(BuildContext context) {
    final st = Settings.instance;
    final tiles = st.carTiles;
    return SectionCard(
      icon: Icons.speed_rounded,
      title: 'تخصيص عداد السرعة',
      subtitle: 'الثيم الوحيد اللي كل حتة فيه ليها أكتر من شكل — ركّب على مزاجك',
      trailing: GlassButton(
        icon: Icons.visibility_rounded,
        label: 'جرّب',
        size: 48,
        onTap: () => DriveMode.open(context, style: 'car'),
      ),
      children: [
        _h('شكل العداد'),
        ChoiceRow<String>(options: carGauges, value: st.carGauge, onChanged: (v) => st.setOpt('carGauge', v)),
        _h('العربية'),
        ChoiceRow<String>(options: carModels, value: st.carModel, onChanged: (v) => st.setOpt('carModel', v)),
        _h('لون العربية'),
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final (c, name) in carColors)
            Tooltip(
              message: name,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => st.setOpt('carColor', c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(c),
                    border: Border.all(color: st.carColor == c ? AppColors.gold : Colors.white24, width: st.carColor == c ? 4 : 1.5),
                  ),
                ),
              ),
            ),
        ]),
        _h('الخانات اللي تظهر (لحد 6)'),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final (id, label, icon) in carTilesAll)
            FilterChip(
              avatar: Icon(icon, size: 20, color: tiles.contains(id) ? AppColors.bg0 : AppColors.gold),
              label: Text(label, style: TextStyle(fontSize: 16, color: tiles.contains(id) ? AppColors.bg0 : AppColors.text)),
              selected: tiles.contains(id),
              showCheckmark: false,
              selectedColor: AppColors.gold,
              backgroundColor: Colors.white.withOpacity(0.06),
              onSelected: (on) {
                final l = [...tiles];
                if (on) {
                  if (l.length >= 6) l.removeAt(0);
                  l.add(id);
                } else {
                  l.remove(id);
                }
                st.setOpt('carTiles', l);
              },
            ),
        ]),
        _h('الوحدة وأقصى رقم'),
        ChoiceRow<bool>(options: const [(false, 'كم/س'), (true, 'ميل/س')], value: st.carMph, onChanged: (v) => st.setOpt('carMph', v)),
        const SizedBox(height: 10),
        ChoiceRow<int>(
          options: const [(140, '140'), (180, '180'), (220, '220'), (260, '260')],
          value: st.carMax,
          onChanged: (v) => st.setOpt('carMax', v),
        ),
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
          title: 'الطريق المتحرك',
          subtitle: 'خطوط الطريق والعجل بيلفوا على قد سرعتك الحقيقية',
          value: st.carRoad,
          onChanged: (v) => st.setOpt('carRoad', v),
        ),
        const SizedBox(height: 8),
        Row(children: [
          GlassButton(icon: Icons.restart_alt_rounded, label: 'صفّر المشوار', size: 48, onTap: Gps.instance.resetTrip),
          const SizedBox(width: 12),
          Expanded(
            child: Text('ضغطة طويلة على خانة المسافة أو الوقت جوه العداد بتصفّرهم برضه',
                style: TextStyle(fontSize: 15, color: AppColors.muted)),
          ),
        ]),
      ],
    );
  }
}
