import 'package:flutter/material.dart';

import '../services/settings.dart';
import 'glass.dart';

class ThemesTab extends StatelessWidget {
  const ThemesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Settings.instance,
      builder: (context, _) {
        final st = Settings.instance;
        final custom = customTheme(st.customColors);
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _ThemeCard(
                t: custom,
                selected: st.themeId == 'custom',
                wide: true,
                badge: 'ألوانك إنت',
                onTap: () => showDialog(context: context, builder: (_) => const _CustomThemeEditor()),
                actionLabel: 'تعديل الألوان',
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 340,
                mainAxisExtent: 190,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final t = appThemes[i];
                  return _ThemeCard(
                    t: t,
                    selected: st.themeId == t.id,
                    onTap: () => st.setTheme(t.id),
                  );
                },
                childCount: appThemes.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final AppThemeData t;
  final bool selected;
  final bool wide;
  final String? badge;
  final String? actionLabel;
  final VoidCallback onTap;
  const _ThemeCard({
    required this.t,
    required this.selected,
    required this.onTap,
    this.wide = false,
    this.badge,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: wide ? 150 : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: selected ? t.gold : Colors.white24, width: selected ? 3 : 1.2),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [t.bg1, t.bg0, t.bg2],
              ),
              boxShadow: selected ? [BoxShadow(color: t.gold.withOpacity(0.35), blurRadius: 24)] : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  Positioned(
                    top: -40,
                    left: -30,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [t.emerald.withOpacity(0.6), t.emerald.withOpacity(0)]),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(t.name,
                              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: t.gold)),
                          if (badge != null) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: t.gold.withOpacity(0.18),
                              ),
                              child: Text(badge!, style: TextStyle(color: t.gold, fontSize: 14)),
                            ),
                          ],
                          const Spacer(),
                          if (selected) Icon(Icons.check_circle_rounded, color: t.gold, size: 30),
                        ]),
                        const Spacer(),
                        Row(children: [
                          for (final c in [t.gold, t.emerald, t.teal, t.bg1])
                            Container(
                              width: 30,
                              height: 30,
                              margin: const EdgeInsetsDirectional.only(end: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c,
                                border: Border.all(color: Colors.white30),
                              ),
                            ),
                          const Spacer(),
                          Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40),
                              gradient: LinearGradient(colors: [t.gold, t.gold.withOpacity(0.7)]),
                            ),
                            child: Text(actionLabel ?? (selected ? 'مُفعّل' : 'تطبيق'),
                                style: TextStyle(color: t.bg0, fontSize: 16, fontWeight: FontWeight.w800)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple HSV colour editor for the four custom colours.
class _CustomThemeEditor extends StatefulWidget {
  const _CustomThemeEditor();

  @override
  State<_CustomThemeEditor> createState() => _CustomThemeEditorState();
}

class _CustomThemeEditorState extends State<_CustomThemeEditor> {
  static const _labels = ['الخلفية', 'الأسطح', 'اللون الأساسي', 'اللون الثانوي'];
  static const _presets = [
    0xFF000000, 0xFF0B0B0D, 0xFF1A0507, 0xFF06283D, 0xFF0C2414, 0xFF1D0F36,
    0xFFE5484D, 0xFF9B111E, 0xFFE6C27A, 0xFF3DDC97, 0xFF5B8CFF, 0xFFFFC371,
    0xFFEC6F9B, 0xFF9D4EDD, 0xFF1FB6D4, 0xFFD9DCE1, 0xFF8A8F98, 0xFFFFFFFF,
  ];

  late List<HSVColor> _c;
  int _slot = 2;

  @override
  void initState() {
    super.initState();
    _c = Settings.instance.customColors.map((v) => HSVColor.fromColor(Color(v))).toList();
  }

  List<int> get _values => _c.map((h) => h.toColor().value).toList();

  @override
  Widget build(BuildContext context) {
    final preview = customTheme(_values);
    final cur = _c[_slot];
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 120, vertical: 40),
      child: Glass(
        radius: 30,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('ثيم مخصص', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              // live preview
              Container(
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(colors: [preview.bg1, preview.bg0, preview.bg2]),
                  border: Border.all(color: preview.gold, width: 2),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [preview.gold, preview.emerald]),
                    ),
                    child: Icon(Icons.play_arrow_rounded, color: preview.bg0, size: 36),
                  ),
                  const SizedBox(width: 16),
                  Text('سورة الكهف', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: preview.gold)),
                  const Spacer(),
                  Text('معاينة', style: TextStyle(color: preview.emerald, fontSize: 18)),
                ]),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (var i = 0; i < 4; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(end: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => setState(() => _slot = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: _slot == i ? AppColors.gold : Colors.white24, width: _slot == i ? 2.5 : 1),
                            ),
                            child: Column(children: [
                              Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _c[i].toColor(),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white30),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(_labels[i], style: const TextStyle(fontSize: 15)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _hsvSlider('اللون', cur.hue, 360,
                  [for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor()],
                  (v) => cur.withHue(v)),
              _hsvSlider('التشبع', cur.saturation, 1,
                  [cur.withSaturation(0).toColor(), cur.withSaturation(1).toColor()], (v) => cur.withSaturation(v)),
              _hsvSlider('الإضاءة', cur.value, 1,
                  [Colors.black, cur.withValue(1).toColor()], (v) => cur.withValue(v)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final p in _presets)
                    InkWell(
                      onTap: () => setState(() => _c[_slot] = HSVColor.fromColor(Color(p))),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Color(p),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white38),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                  child: GlassButton(
                    icon: Icons.check_rounded,
                    label: 'حفظ وتطبيق',
                    primary: true,
                    onTap: () async {
                      await Settings.instance.setCustomColors(_values);
                      await Settings.instance.setTheme('custom');
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: GlassButton(
                      icon: Icons.close_rounded, label: 'إلغاء', onTap: () => Navigator.pop(context)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hsvSlider(String label, double value, double max, List<Color> track, HSVColor Function(double) apply) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: TextStyle(fontSize: 17, color: AppColors.muted))),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(colors: track),
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                      thumbColor: Colors.white,
                      trackHeight: 14,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 13),
                    ),
                    child: Slider(
                      min: 0,
                      max: max,
                      value: value.clamp(0.0, max).toDouble(),
                      onChanged: (v) => setState(() => _c[_slot] = apply(v)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
