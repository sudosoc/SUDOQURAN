import 'dart:async';

import 'package:flutter/material.dart';

import '../services/library.dart';
import '../services/player.dart';
import '../services/prayer.dart';
import '../services/settings.dart';
import '../services/sources.dart';
import 'glass.dart';
import 'settings_widgets.dart';

/// Main "الصلاة" section (right rail): countdown, times, alerts, adhan voices.
class PrayerSection extends StatefulWidget {
  const PrayerSection({super.key});

  @override
  State<PrayerSection> createState() => _PrayerSectionState();
}

class _PrayerSectionState extends State<PrayerSection> {
  late final Timer _t = Timer.periodic(const Duration(seconds: 1), (_) {
    if (mounted) setState(() {});
  });

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = Settings.instance;
    final pr = Prayer.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([st, pr, Library.instance, Sources.instance, Player.instance]),
      builder: (context, _) {
        final now = DateTime.now();
        final next = pr.next;
        final left = next.$2.difference(now);
        final times = pr.today;
        final adhans = Sources.instance.adhan;
        final sel = Library.instance.selectedAdhanUrl;
        final hh = left.inHours.toString().padLeft(2, '0');
        final mm = left.inMinutes.remainder(60).toString().padLeft(2, '0');
        final ss = left.inSeconds.remainder(60).toString().padLeft(2, '0');
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // ------------------------------------------------------------ hero
            Glass(
              radius: 30,
              padding: const EdgeInsets.all(26),
              borderColor: AppColors.gold.withOpacity(0.5),
              child: Row(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [AppColors.gold, AppColors.emerald]),
                      boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.35), blurRadius: 30)],
                    ),
                    child: Icon(Icons.mosque_rounded, size: 66, color: AppColors.bg0),
                  ),
                  const SizedBox(width: 26),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الصلاة القادمة', style: TextStyle(color: AppColors.gold, fontSize: 20)),
                        Text(next.$1, style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, height: 1.1)),
                        Text('${fmtClock(next.$2, h24: st.clock24)} · ${cityById(st.prayerCity).name}',
                            style: TextStyle(color: AppColors.muted, fontSize: 19)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text('$hh:$mm:$ss',
                            style: TextStyle(
                                fontSize: 60,
                                fontWeight: FontWeight.w300,
                                color: AppColors.gold,
                                fontFeatures: const [FontFeature.tabularFigures()])),
                      ),
                      Text(hijriText(now, st.hijriOffset),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      Text('${now.day}/${now.month}/${now.year}', style: TextStyle(color: AppColors.muted, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ---------------------------------------------------------- times
            Row(
              children: [
                for (var i = 0; i < times.length; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: prayerNames[i] == next.$1 && i != 1
                            ? LinearGradient(colors: [AppColors.gold.withOpacity(0.35), AppColors.emerald.withOpacity(0.15)])
                            : null,
                        color: prayerNames[i] == next.$1 && i != 1 ? null : Colors.white.withOpacity(0.05),
                        border: Border.all(
                            color: prayerNames[i] == next.$1 && i != 1 ? AppColors.gold : Colors.white12,
                            width: prayerNames[i] == next.$1 && i != 1 ? 2 : 1),
                      ),
                      child: Column(children: [
                        Icon(
                          const [
                            Icons.nights_stay_rounded,
                            Icons.wb_twilight_rounded,
                            Icons.wb_sunny_rounded,
                            Icons.sunny_snowing,
                            Icons.wb_twilight_rounded,
                            Icons.dark_mode_rounded,
                          ][i],
                          color: times[i].isBefore(now) && prayerNames[i] != next.$1 ? AppColors.muted : AppColors.gold,
                          size: 30,
                        ),
                        const SizedBox(height: 6),
                        Text(prayerNames[i], style: TextStyle(fontSize: 18, color: AppColors.muted)),
                        const SizedBox(height: 4),
                        Text(fmtClock(times[i], h24: st.clock24),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      ]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // ------------------------------------------------------- alerts
            SectionCard(
              icon: Icons.notifications_active_rounded,
              title: 'تنبيهات الأذان',
              children: [
                ToggleRow(
                  title: 'تنبيه وقت الأذان',
                  subtitle: 'يوقف القرآن ويظهر تنبيه، وبعدها يكمّل',
                  value: st.prayerEnabled,
                  onChanged: (v) => st.setOpt('prayerEnabled', v),
                ),
                ToggleRow(
                  title: 'التنبيه والتطبيق مقفول',
                  subtitle: 'إشعار من النظام + صوت الأذان حتى لو التطبيق مش مفتوح (الأذان لازم يكون متحمّل)',
                  value: st.bgAdhan,
                  onChanged: (v) => st.setOpt('bgAdhan', v),
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
                const SizedBox(height: 10),
                const Text('تنبيه قبل الأذان', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ChoiceRow<int>(
                  options: const [(0, 'مقفول'), (5, '5 دقايق'), (10, '10 دقايق'), (15, '15 دقيقة'), (20, '20 دقيقة')],
                  value: st.preAlert,
                  onChanged: (v) => st.setOpt('preAlert', v),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: GlassButton(icon: Icons.play_circle_rounded, label: 'جرّب التنبيه دلوقتي', size: 54, onTap: pr.test),
                ),
              ],
            ),
            // ------------------------------------------------- adhan voices
            SectionCard(
              icon: Icons.record_voice_over_rounded,
              title: 'صوت الأذان',
              subtitle: adhans.isEmpty ? 'لسه بندوّر على أصوات أذان…' : 'اسمع أي صوت واختار — بيتحمّل علشان يشتغل أوفلاين',
              children: [
                for (final a in adhans)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: a.url == sel ? AppColors.gold.withOpacity(0.14) : Colors.white.withOpacity(0.04),
                      border: Border.all(color: a.url == sel ? AppColors.gold : Colors.white12),
                    ),
                    child: Row(children: [
                      InkWell(
                        onTap: () async {
                          await st.setOpt('adhanUrl', a.url);
                          await Library.instance.downloadAdhan(a.url);
                        },
                        child: Icon(
                          a.url == sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          color: AppColors.gold,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18)),
                      ),
                      if (Library.instance.adhanFile(a.url) != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.offline_pin_rounded, color: AppColors.emerald, size: 24),
                        ),
                      GlassButton(
                        icon: Player.instance.kind == PlayKind.special && Player.instance.title == 'تجربة الأذان'
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        size: 48,
                        onTap: () => Player.instance.kind == PlayKind.special
                            ? Player.instance.stopInterrupt()
                            : Player.instance.previewAdhan(a.url),
                      ),
                    ]),
                  ),
              ],
            ),
            // ------------------------------------------------------- location
            SectionCard(
              icon: Icons.location_city_rounded,
              title: 'المدينة',
              subtitle: 'المواقيت بتتحسب أوفلاين — الهيئة المصرية العامة للمساحة',
              children: [
                ChoiceRow<String>(
                  options: [for (final c in cities) (c.id, c.name)],
                  value: st.prayerCity,
                  onChanged: (v) => st.setOpt('prayerCity', v),
                ),
                const SizedBox(height: 14),
                const Text('ضبط التاريخ الهجري', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ChoiceRow<int>(
                  options: const [(-2, '−2 يوم'), (-1, '−1 يوم'), (0, 'بدون'), (1, '+1 يوم'), (2, '+2 يوم')],
                  value: st.hijriOffset,
                  onChanged: (v) => st.setOpt('hijriOffset', v),
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
