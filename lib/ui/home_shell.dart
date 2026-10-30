import 'package:flutter/material.dart';

import 'glass.dart';
import 'now_playing.dart';
import 'quran_page.dart';
import 'ruqyah_page.dart';
import 'settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _items = [
    (Icons.menu_book_rounded, 'القرآن'),
    (Icons.shield_moon_rounded, 'الرقية'),
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
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // RTL: first child sits on the right edge.
                    _SideRail(
                      index: _tab,
                      items: _items,
                      onTap: (i) => setState(() => _tab = i),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: IndexedStack(
                        index: _tab,
                        children: const [
                          QuranSection(),
                          RuqyahSection(),
                          SettingsSection(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    // Left side = closest to the driver in a left-hand-drive car.
                    SizedBox(width: playerWidth, child: const NowPlayingPanel()),
                  ],
                );
              }),
            ),
          ),
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
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [AppColors.gold, Color(0xFFB8893F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.4), blurRadius: 24)],
              ),
              child: const Text('۞', style: TextStyle(fontSize: 34, color: AppColors.bg0)),
            ),
            const SizedBox(height: 30),
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _RailItem(
                  icon: items[i].$1,
                  label: items[i].$2,
                  selected: index == i,
                  onTap: () => onTap(i),
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
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: selected ? AppColors.gold.withOpacity(0.18) : Colors.transparent,
            border: Border.all(
                color: selected ? AppColors.gold.withOpacity(0.7) : Colors.transparent, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, size: 38, color: selected ? AppColors.gold : AppColors.muted),
              const SizedBox(height: 6),
              Text(label,
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
