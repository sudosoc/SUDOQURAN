import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/settings.dart';
import 'glass.dart';
import 'settings_widgets.dart';

/// Save / restore all settings (themes, custom colours, drive style,
/// prayer city, widget style, last session…) to a JSON file.
class BackupCard extends StatelessWidget {
  const BackupCard({super.key});

  static const _ch = MethodChannel('sudoquran/backup');

  Future<void> _save(BuildContext context) async {
    try {
      final now = DateTime.now();
      final name = 'sudoquran-backup-${now.year}-${now.month}-${now.day}.json';
      final json = const JsonEncoder.withIndent(' ').convert(Settings.instance.exportMap());
      final r = await _ch.invokeMethod<String>('save', {'json': json, 'name': name});
      if (context.mounted && r != null) toast(context, 'اتحفظت النسخة الاحتياطية ✓');
    } catch (e) {
      if (context.mounted) toast(context, 'معرفناش نحفظ: $e');
    }
  }

  Future<void> _load(BuildContext context) async {
    try {
      final text = await _ch.invokeMethod<String>('load');
      if (text == null) return;
      await Settings.instance.importMap(Map<String, dynamic>.from(jsonDecode(text) as Map));
      if (context.mounted) toast(context, 'رجّعنا إعداداتك ✓');
    } catch (e) {
      if (context.mounted) toast(context, 'الملف ده مش نسخة احتياطية صالحة');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.backup_rounded,
      title: 'نسخة احتياطية',
      subtitle: 'احفظ كل إعداداتك وثيماتك في ملف، ورجّعها على أي جهاز',
      children: [
        Row(children: [
          Expanded(
            child: GlassButton(icon: Icons.save_alt_rounded, label: 'حفظ نسخة', size: 60, primary: true, onTap: () => _save(context)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GlassButton(icon: Icons.restore_rounded, label: 'استرجاع', size: 60, onTap: () => _load(context)),
          ),
        ]),
      ],
    );
  }
}
