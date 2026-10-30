import 'package:flutter/material.dart';

import '../data/reciters.dart';
import '../services/library.dart';
import '../services/settings.dart';
import 'glass.dart';

class SettingsSection extends StatefulWidget {
  const SettingsSection({super.key});

  @override
  State<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<SettingsSection> {
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
      listenable: Listenable.merge([s, lib]),
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 16),
              child: Text('الإعدادات', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
            ),
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
            Glass(
              radius: 26,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storage_rounded, color: AppColors.gold, size: 30),
                      const SizedBox(width: 12),
                      const Text('المساحة المستخدمة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      FutureBuilder<int>(
                        future: _used,
                        builder: (context, snap) => Text(
                          snap.hasData ? formatBytes(snap.data!) : '...',
                          style: const TextStyle(fontSize: 22, color: AppColors.emerald),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GlassButton(
                        icon: Icons.refresh_rounded,
                        size: 54,
                        onTap: () => setState(() => _used = lib.usedBytes()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('المصحف الكامل للقارئ الواحد حوالي 0.8–1.5 جيجا (المساحة عندك 128 جيجا)',
                      style: TextStyle(color: AppColors.muted, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Glass(
              radius: 26,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_sync_rounded, color: AppColors.gold, size: 30),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('مصادر التلاوات (mp3quran.net)',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      ),
                      if (lib.resolving)
                        const SizedBox(
                            width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3))
                      else
                        GlassButton(
                          icon: Icons.sync_rounded,
                          label: 'تحديث',
                          size: 54,
                          onTap: lib.refreshCatalogue,
                        ),
                    ],
                  ),
                  if (lib.resolveError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(lib.resolveError!,
                          style: const TextStyle(color: Colors.orangeAccent, fontSize: 16)),
                    ),
                  const SizedBox(height: 10),
                  for (final r in reciters)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            lib.isOnline(r) ? Icons.check_circle_rounded : Icons.usb_rounded,
                            color: lib.isOnline(r) ? AppColors.emerald : AppColors.gold,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                              width: 240,
                              child: Text(r.name, style: const TextStyle(fontSize: 18))),
                          Expanded(
                            child: Text(
                              lib.isOnline(r)
                                  ? '${lib.activeMoshaf(r)!.name} · ${lib.localSurahs(r).length}/114 محمل'
                                  : 'مش موجود أونلاين — استيراد من فلاشة أو رابط مخصص',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, color: AppColors.muted),
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
                Text(subtitle, style: const TextStyle(fontSize: 15, color: AppColors.muted)),
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
