import 'package:flutter/material.dart';

import '../services/settings.dart';
import 'glass.dart';

class ThemesTab extends StatelessWidget {
  const ThemesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Settings.instance,
      builder: (context, _) => GridView.builder(
        padding: const EdgeInsets.only(bottom: 20),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 360,
          mainAxisExtent: 200,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: appThemes.length,
        itemBuilder: (context, i) {
          final t = appThemes[i];
          final selected = Settings.instance.themeId == t.id;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: () => Settings.instance.setTheme(t.id),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: selected ? t.gold : Colors.white24, width: selected ? 3 : 1.2),
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [t.bg1, t.bg0, t.bg2],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -30,
                      left: -20,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [t.emerald.withOpacity(0.55), t.emerald.withOpacity(0)]),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(t.name,
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: t.gold)),
                            const Spacer(),
                            if (selected) Icon(Icons.check_circle_rounded, color: t.gold, size: 32),
                          ]),
                          const Spacer(),
                          Row(children: [
                            for (final c in [t.gold, t.emerald, t.teal, t.bg1])
                              Container(
                                width: 34,
                                height: 34,
                                margin: const EdgeInsetsDirectional.only(end: 10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: c,
                                  border: Border.all(color: Colors.white30),
                                ),
                              ),
                          ]),
                          const SizedBox(height: 14),
                          Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40),
                              gradient: LinearGradient(colors: [t.gold, t.gold.withOpacity(0.7)]),
                            ),
                            child: Text(selected ? 'مُفعّل' : 'تطبيق الثيم',
                                style: TextStyle(color: t.bg0, fontSize: 18, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
