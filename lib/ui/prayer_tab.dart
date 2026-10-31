import 'package:flutter/material.dart';

import '../services/library.dart';
import '../services/prayer.dart';
import '../services/settings.dart';
import '../services/sources.dart';
import 'glass.dart';
import 'settings_widgets.dart';

class PrayerTab extends StatelessWidget {
  const PrayerTab({super.key});

  @override
  Widget build(BuildContext context) {
    final st = Settings.instance;
    final pr = Prayer.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([st, pr, Library.instance, Sources.instance]),
      builder: (context, _) {
        final next = pr.next;
        final times = pr.today;
        final adhans = Sources.instance.adhan;
        final sel = Library.instance.selectedAdhanUrl;
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SectionCard(
              icon: Icons.mosque_rounded,
              title: 'مواقيت الصلاة',
              subtitle: '${cityById(st.prayerCity).name} · الهيئة المصرية العامة للمساحة',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: AppColors.gold.withOpacity(0.18),
                ),
                child: Text('${next.$1} بعد ${fmtCountdown(next.$2.difference(DateTime.now()))}',
                    style: TextStyle(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              children: [
                Row(
                  children: [
                    for (var i = 0; i < times.length; i++)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: prayerNames[i] == next.$1 && i != 1
                                ? AppColors.gold.withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                            border: Border.all(
                                color: prayerNames[i] == next.$1 && i != 1 ? AppColors.gold : Colors.white12),
                          ),
                          child: Column(children: [
                            Text(prayerNames[i], style: TextStyle(fontSize: 17, color: AppColors.muted)),
                            const SizedBox(height: 4),
                            Text(fmtClock(times[i], h24: st.clock24),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                          ]),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('المدينة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ChoiceRow<String>(
                  options: [for (final c in cities) (c.id, c.name)],
                  value: st.prayerCity,
                  onChanged: (v) => st.setOpt('prayerCity', v),
                ),
              ],
            ),
            SectionCard(
              icon: Icons.notifications_active_rounded,
              title: 'تنبيه الأذان',
              children: [
                ToggleRow(
                  title: 'تنبيه وقت الأذان',
                  subtitle: 'يوقف القرآن ويظهر تنبيه وقت كل صلاة (والتطبيق شغال)',
                  value: st.prayerEnabled,
                  onChanged: (v) => st.setOpt('prayerEnabled', v),
                ),
                ToggleRow(
                  title: 'تشغيل صوت الأذان',
                  subtitle: 'لو مقفول: إيقاف القرآن + تنبيه بس',
                  value: st.adhanSound,
                  onChanged: (v) => st.setOpt('adhanSound', v),
                ),
                ToggleRow(
                  title: 'كمّل القرآن بعد الأذان',
                  value: st.resumeAfterAdhan,
                  onChanged: (v) => st.setOpt('resumeAfterAdhan', v),
                ),
                if (adhans.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('صوت الأذان', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final a in adhans)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        st.setOpt('adhanUrl', a.url);
                        Library.instance.downloadAdhan(a.url);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        child: Row(children: [
                          Icon(a.url == sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              color: AppColors.gold),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(a.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17)),
                          ),
                          if (Library.instance.adhanFile(a.url) != null)
                            Icon(Icons.offline_pin_rounded, color: AppColors.emerald, size: 22),
                        ]),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: GlassButton(
                    icon: Icons.play_circle_rounded,
                    label: 'جرّب التنبيه دلوقتي',
                    size: 54,
                    onTap: pr.test,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// دعاء الركوب settings (shown in the General tab).
class DuaCard extends StatelessWidget {
  const DuaCard({super.key});

  @override
  Widget build(BuildContext context) {
    final st = Settings.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([st, Sources.instance, Library.instance]),
      builder: (context, _) {
        final ea = Sources.instance.everyAyah;
        final options = <(String, String)>[
          for (final e in ea.entries) ('ayat:${e.key}', 'آيات الدعاء — ${_name(e.key)}'),
          if (ea.isEmpty) ('ayat:maher', 'آيات الدعاء — ماهر المعيقلي'),
          for (final t in Sources.instance.duaRukub.take(4)) ('url:${t.url}', t.title),
        ];
        final ready = Library.instance.duaFiles().length == Library.instance.duaUrls().length;
        return SectionCard(
          icon: Icons.directions_car_filled_rounded,
          title: 'دعاء الركوب',
          subtitle: '﴿سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَٰذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ﴾ — أول ما التطبيق يفتح',
          children: [
            ToggleRow(
              title: 'تشغيل دعاء الركوب عند فتح التطبيق',
              subtitle: ready ? 'جاهز أوفلاين ✓' : 'هيتحمّل أول مرة يشتغل',
              value: st.duaEnabled,
              onChanged: (v) => st.setOpt('duaEnabled', v),
            ),
            const SizedBox(height: 8),
            ChoiceRow<String>(
              options: options,
              value: st.duaSource,
              onChanged: (v) async {
                await st.setOpt('duaSource', v);
                await Library.instance.downloadDua(v);
              },
            ),
          ],
        );
      },
    );
  }

  static String _name(String id) => const {
        'maher': 'ماهر المعيقلي',
        'minshawi': 'المنشاوي',
        'afasy': 'العفاسي',
        'basit': 'عبد الباسط',
        'ghamdi': 'سعد الغامدي',
        'dosari': 'ياسر الدوسري',
        'tablawi': 'الطبلاوي',
        'banna': 'محمود البنا',
      }[id] ??
      id;
}
