import 'package:flutter/material.dart';

import '../services/library.dart';
import '../services/settings.dart';
import 'adhan_banner.dart';
import 'drive_mode.dart';
import 'glass.dart';
import 'now_playing.dart';
import 'prayer_tab.dart';
import 'quran_page.dart';
import 'radio_page.dart';
import 'ruqyah_page.dart';
import 'settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static int _tab = 0;
  static bool _launched = false;

  @override
  void initState() {
    super.initState();
    if (!_launched) {
      _launched = true;
      if (Settings.instance.driveOnLaunch) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) DriveMode.open(context);
        });
      }
    }
  }

  static const _items = [
    (Icons.menu_book_rounded, 'القرآن'),
    (Icons.shield_moon_rounded, 'الرقية\nوالأذكار'),
    (Icons.mosque_rounded, 'الصلاة'),
    (Icons.sensors_rounded, 'البث\nالمباشر'),
    (Icons.tune_rounded, 'الإعدادات'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: LayoutBuilder(builder: (context, c) {
                final playerWidth = (c.maxWidth * 0.30).clamp(340.0, 440.0).toDouble();
                final rail = _SideRail(
                  index: _tab,
                  items: _items,
                  onTap: (i) => setState(() => _tab = i),
                );
                final content = Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: const [
                      QuranSection(),
                      RuqyahSection(),
                      PrayerSection(),
                      RadioSection(),
                      SettingsSection(),
                    ],
                  ),
                );
                final player = SizedBox(width: playerWidth, child: const NowPlayingPanel());
                // RTL row: first child = right edge. "left" puts the player on the
                // driver's side in a left-hand-drive car.
                final playerLeft = Settings.instance.playerSide == 'left';
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: playerLeft
                      ? [rail, const SizedBox(width: 18), content, const SizedBox(width: 18), player]
                      : [player, const SizedBox(width: 18), content, const SizedBox(width: 18), rail],
                );
              }),
            ),
          ),
          const AdhanBanner(),
        ],
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  final int index;
  final List<(IconData, String)> items;
  final ValueChanged<int> onTap;
  const _SideRail({required this.index, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 30,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 10),
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.35), blurRadius: 24)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset('assets/icon.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 26),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(children: [
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RailItem(
                        icon: items[i].$1,
                        label: items[i].$2,
                        selected: index == i,
                        onTap: () => onTap(i),
                      ),
                    ),
                ]),
              ),
            ),
            ListenableBuilder(
              listenable: Library.instance,
              builder: (context, _) {
                final active = Library.instance.jobs.values.where((j) => !j.finished).toList();
                if (active.isEmpty) return const SizedBox.shrink();
                final f = active.fold<double>(0, (a, j) => a + j.fraction) / active.length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Tooltip(
                    message: 'جاري التحميل',
                    child: Stack(alignment: Alignment.center, children: [
                      SizedBox(
                        width: 54,
                        height: 54,
                        child: CircularProgressIndicator(
                            value: f, strokeWidth: 4, color: AppColors.emerald, backgroundColor: Colors.white12),
                      ),
                      Icon(Icons.downloading_rounded, color: AppColors.emerald, size: 28),
                    ]),
                  ),
                );
              },
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => DriveMode.open(context),
                child: Ink(
                  width: 96,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [AppColors.gold, AppColors.gold.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(children: [
                    Icon(Icons.directions_car_rounded, color: AppColors.bg0, size: 38),
                    const SizedBox(height: 4),
                    Text('السواقة',
                        style: TextStyle(color: AppColors.bg0, fontSize: 17, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RailItem(
      {required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 96,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: selected ? AppColors.gold.withOpacity(0.18) : Colors.transparent,
            border: Border.all(
                color: selected ? AppColors.gold.withOpacity(0.7) : Colors.transparent, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, size: 34, color: selected ? AppColors.gold : AppColors.muted),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected ? AppColors.gold : AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
