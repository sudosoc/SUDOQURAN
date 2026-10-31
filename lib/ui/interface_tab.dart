import 'package:flutter/material.dart';

import '../services/settings.dart';
import '../services/widget_bridge.dart';
import 'glass.dart';
import 'settings_widgets.dart';

class InterfaceTab extends StatefulWidget {
  const InterfaceTab({super.key});

  @override
  State<InterfaceTab> createState() => _InterfaceTabState();
}

class _InterfaceTabState extends State<InterfaceTab> {
  double? _scale; // applied on release so the screen doesn't rebuild while dragging
  double? _blur;

  @override
  Widget build(BuildContext context) {
    final st = Settings.instance;
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SectionCard(
            icon: Icons.text_fields_rounded,
            title: 'الحجم والخطوط',
            children: [
              Row(children: [
                Expanded(
                  child: SliderRow(
                    title: 'حجم الكلام',
                    value: _scale ?? st.uiScale,
                    min: 0.8,
                    max: 1.4,
                    divisions: 12,
                    label: (v) => '${(v * 100).round()}%',
                    onChanged: (v) => setState(() => _scale = v),
                  ),
                ),
                if (_scale != null && _scale != st.uiScale)
                  GlassButton(
                    icon: Icons.check_rounded,
                    label: 'تطبيق',
                    size: 50,
                    primary: true,
                    onTap: () {
                      st.setOpt('uiScale', _scale);
                      _scale = null;
                    },
                  ),
              ]),
            ],
          ),
          SectionCard(
            icon: Icons.wallpaper_rounded,
            title: 'خلفية حية',
            subtitle: 'خلفية متحركة للتطبيق كله',
            children: [
              ChoiceRow<String>(
                options: const [
                  ('static', 'ثابتة'),
                  ('stars', 'سماء ونجوم وهلال'),
                  ('lanterns', 'فوانيس طايرة'),
                  ('aurora', 'شفق متحرك'),
                  ('geometry', 'زخرفة بتلف'),
                ],
                value: st.wallpaper,
                onChanged: (v) => st.setOpt('wallpaper', v),
              ),
            ],
          ),
          SectionCard(
            icon: Icons.blur_on_rounded,
            title: 'الزجاج والخلفية',
            subtitle: 'لو الشاشة تقيلة قلّل التغبيش',
            children: [
              Row(children: [
                Expanded(
                  child: SliderRow(
                    title: 'التغبيش (Blur)',
                    value: _blur ?? st.blur,
                    min: 0,
                    max: 40,
                    divisions: 8,
                    label: (v) => v < 1 ? 'مقفول' : '${v.round()}',
                    onChanged: (v) => setState(() => _blur = v),
                  ),
                ),
                if (_blur != null && _blur != st.blur)
                  GlassButton(
                    icon: Icons.check_rounded,
                    label: 'تطبيق',
                    size: 50,
                    primary: true,
                    onTap: () {
                      st.setOpt('blur', _blur);
                      _blur = null;
                    },
                  ),
              ]),
              ToggleRow(
                title: 'زخرفة النجوم في الخلفية',
                value: st.pattern,
                onChanged: (v) => st.setOpt('pattern', v),
              ),
              ToggleRow(
                title: 'الأنيميشن',
                subtitle: 'اقفلها لو عايز التطبيق أسرع على الشاشة',
                value: st.animations,
                onChanged: (v) => st.setOpt('animations', v),
              ),
            ],
          ),
          SectionCard(
            icon: Icons.view_quilt_rounded,
            title: 'ترتيب الشاشة',
            children: [
              const Text('مكان المشغّل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ChoiceRow<String>(
                options: const [('left', 'على الشمال (جنب السواق)'), ('right', 'على اليمين')],
                value: st.playerSide,
                onChanged: (v) => st.setOpt('playerSide', v),
              ),
              const SizedBox(height: 16),
              const Text('شكل الساعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ChoiceRow<bool>(
                options: const [(false, '12 ساعة (ص/م)'), (true, '24 ساعة')],
                value: st.clock24,
                onChanged: (v) => st.setOpt('clock24', v),
              ),
            ],
          ),
          SectionCard(
            icon: Icons.widgets_rounded,
            title: 'الويدجت',
            subtitle: 'شكل الويدجت اللي على الشاشة الرئيسية',
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final (id, name, bg, fg) in const [
                    ('glass', 'زجاجي', Color(0xE60B2A33), Color(0xFFE6C27A)),
                    ('amoled', 'أسود', Color(0xFF000000), Color(0xFFE6C27A)),
                    ('gold', 'ذهبي', Color(0xFFE6C27A), Color(0xFF1A1206)),
                    ('crimson', 'أحمر ملكي', Color(0xFF1A0507), Color(0xFFE5484D)),
                    ('clear', 'شفاف', Color(0x33000000), Color(0xFFFFFFFF)),
                  ])
                    InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () async {
                        await st.setOpt('widgetStyle', id);
                        HomeWidgetBridge.refresh();
                      },
                      child: Container(
                        width: 220,
                        height: 76,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                              color: st.widgetStyle == id ? AppColors.gold : Colors.white24,
                              width: st.widgetStyle == id ? 3 : 1),
                        ),
                        child: Row(children: [
                          Icon(Icons.play_circle_fill_rounded, color: fg, size: 38),
                          const SizedBox(width: 10),
                          Text(name, style: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
