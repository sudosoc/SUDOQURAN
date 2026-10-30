import 'package:flutter/material.dart';

import '../data/reciters.dart';
import '../services/library.dart';
import '../services/settings.dart';
import '../services/sources.dart';
import 'about_tab.dart';
import 'downloads_page.dart';
import 'glass.dart';
import 'photos_card.dart';
import 'themes_tab.dart';

class SettingsSection extends StatefulWidget {
  const SettingsSection({super.key});

  @override
  State<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<SettingsSection> {
  static int _tab = 0;

  static const _tabs = [
    (Icons.tune_rounded, 'عام'),
    (Icons.download_for_offline_rounded, 'إدارة التحميل'),
    (Icons.palette_rounded, 'الثيمات'),
    (Icons.person_rounded, 'عن المطور'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
          child: Row(
            children: [
              const Text('الإعدادات', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
              const SizedBox(width: 24),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < _tabs.length; i++) ...[
                        _TabChip(
                          icon: _tabs[i].$1,
                          label: _tabs[i].$2,
                          selected: _tab == i,
                          onTap: () => setState(() => _tab = i),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: const [
              _GeneralTab(),
              DownloadsPage(),
              ThemesTab(),
              AboutTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabChip({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            color: selected ? AppColors.gold.withOpacity(0.2) : Colors.white.withOpacity(0.05),
            border: Border.all(color: selected ? AppColors.gold : Colors.white.withOpacity(0.12), width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: selected ? AppColors.gold : AppColors.muted, size: 26),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? AppColors.text : AppColors.muted)),
          ]),
        ),
      ),
    );
  }
}

class _GeneralTab extends StatefulWidget {
  const _GeneralTab();

  @override
  State<_GeneralTab> createState() => _GeneralTabState();
}

class _GeneralTabState extends State<_GeneralTab> {
  Future<int>? _used;

  @override
  void initState() {
    super.initState();
    _used = Library.instance.usedBytes();
  }

  @override
  Widget build(BuildContext context) {
    final s = Settings.instance;
    final lib = Library.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([s, lib, Sources.instance]),
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            const _DownloadEverythingCard(),
            const SizedBox(height: 16),
            Glass(
              radius: 26,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  _SwitchRow(
                    icon: Icons.wifi_rounded,
                    title: 'تشغيل أونلاين للسور غير المحملة',
                    subtitle: 'لو مقفول، التطبيق يشغل اللي على الجهاز بس (أوفلاين 100%)',
                    value: s.allowStreaming,
                    onChanged: s.setAllowStreaming,
                  ),
                  const Divider(color: Colors.white12),
                  _SwitchRow(
                    icon: Icons.cloud_download_rounded,
                    title: 'كمّل التحميل كل ما التطبيق يفتح',
                    subtitle: 'مفيد لو العربية بتقفل والتحميل مخلصش — خلي بالك من باقة النت',
                    value: s.autoDownload,
                    onChanged: s.setAutoDownload,
                  ),
                  const Divider(color: Colors.white12),
                  _SwitchRow(
                    icon: Icons.directions_car_rounded,
                    title: 'افتح على وضع السواقة',
                    subtitle: 'أول ما التطبيق يفتح يدخل على الشاشة الكبيرة على طول',
                    value: s.driveOnLaunch,
                    onChanged: s.setDriveOnLaunch,
                  ),
                  const Divider(color: Colors.white12),
                  _SwitchRow(
                    icon: Icons.play_circle_rounded,
                    title: 'استكمال التلاوة تلقائيًا',
                    subtitle: 'أول ما العربية تدور والتطبيق يفتح، يكمل من مكان ما وقف',
                    value: s.autoResume,
                    onChanged: s.setAutoResume,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const PhotosCard(),
            const SizedBox(height: 16),
            Glass(
              radius: 26,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_sync_rounded, color: AppColors.gold, size: 30),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('مصادر التلاوات',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      ),
                      if (Sources.instance.refreshing)
                        const SizedBox(
                            width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3))
                      else
                        GlassButton(
                          icon: Icons.sync_rounded,
                          label: 'تحديث',
                          size: 54,
                          onTap: Sources.instance.refresh,
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      Sources.instance.error ??
                          'mp3quran · quranicaudio · archive.org — آخر تحديث: ${Sources.instance.generated?.replaceAll('T', ' ').replaceAll('Z', '') ?? '—'}',
                      style: TextStyle(
                          color: Sources.instance.error != null ? Colors.orangeAccent : AppColors.muted,
                          fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final r in reciters)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            lib.reciterComplete(r)
                                ? Icons.offline_pin_rounded
                                : lib.available(r).isNotEmpty
                                    ? Icons.cloud_done_rounded
                                    : Icons.hourglass_top_rounded,
                            color: lib.reciterComplete(r)
                                ? AppColors.emerald
                                : lib.available(r).isNotEmpty
                                    ? AppColors.teal
                                    : AppColors.gold,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          SizedBox(width: 240, child: Text(r.name, style: const TextStyle(fontSize: 18))),
                          Expanded(
                            child: Text(
                              lib.available(r).isEmpty
                                  ? 'لسه مفيش مصدر'
                                  : 'متاح ${lib.available(r).length} · محمل ${lib.localSurahs(r).length}'
                                      '${Sources.instance.labels[r.id] != null ? ' · ${Sources.instance.labels[r.id]}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15, color: AppColors.muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text('SUDOQURAN · by SUDOSOC',
                  style: TextStyle(color: Colors.white38, fontSize: 15, letterSpacing: 2)),
            ),
          ],
        );
      },
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                Text(subtitle, style: TextStyle(fontSize: 15, color: AppColors.muted)),
              ],
            ),
          ),
          Transform.scale(
            scale: 1.3,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.bg0,
              activeTrackColor: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadEverythingCard extends StatelessWidget {
  const _DownloadEverythingCard();

  @override
  Widget build(BuildContext context) {
    final lib = Library.instance;
    final running = lib.everythingRunning;
    final totalAvail = reciters.fold<int>(0, (a, r) => a + lib.available(r).length);
    final totalLocal = reciters.fold<int>(
        0, (a, r) => a + lib.localSurahs(r).intersection(lib.available(r)).length);
    final frac = totalAvail == 0 ? 0.0 : totalLocal / totalAvail;
    return Glass(
      radius: 26,
      padding: const EdgeInsets.all(22),
      borderColor: AppColors.gold.withOpacity(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.download_for_offline_rounded, color: AppColors.gold, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تحميل كل حاجة للأوفلاين',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    Text(
                      running
                          ? 'بيحمّل دلوقتي: ${lib.everythingCurrent ?? '...'}'
                          : 'كل المصاحف + الرقية — تقريبًا 15–20 جيجا، الأفضل على واي فاي',
                      style: TextStyle(color: AppColors.muted, fontSize: 16),
                    ),
                  ],
                ),
              ),
              running
                  ? GlassButton(
                      icon: Icons.stop_rounded,
                      label: 'إيقاف',
                      size: 64,
                      onTap: lib.stopEverything)
                  : GlassButton(
                      icon: Icons.download_rounded,
                      label: frac >= 1 ? 'كله متحمل ✓' : 'ابدأ التحميل',
                      size: 64,
                      primary: frac < 1,
                      onTap: frac >= 1 ? null : lib.downloadEverything),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: frac,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: AppColors.emerald,
            backgroundColor: Colors.white12,
          ),
          const SizedBox(height: 6),
          Text('$totalLocal من $totalAvail سورة على الجهاز',
              style: TextStyle(color: AppColors.muted, fontSize: 15)),
        ],
      ),
    );
  }
}
