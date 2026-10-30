import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/library.dart';
import 'glass.dart';

class ImportSelection {
  final String? folder;
  final List<String>? files;
  const ImportSelection({this.folder, this.files});
}

/// Asks where to import from (folder on USB / SD, or individual files).
Future<ImportSelection?> pickImportSource(BuildContext context, {required String hint}) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 200, vertical: 80),
      child: Glass(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('استيراد ملفات صوتية',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(hint, style: const TextStyle(color: AppColors.muted, fontSize: 17)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    icon: Icons.folder_open_rounded,
                    label: 'اختيار مجلد',
                    size: 72,
                    primary: true,
                    onTap: () => Navigator.pop(ctx, 'folder'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GlassButton(
                    icon: Icons.library_music_rounded,
                    label: 'اختيار ملفات',
                    size: 72,
                    onTap: () => Navigator.pop(ctx, 'files'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null) return null;
  if (!await Library.ensureAudioPermission()) {
    if (context.mounted) toast(context, 'محتاج إذن الوصول للملفات الصوتية');
    return null;
  }
  if (choice == 'folder') {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return null;
    return ImportSelection(folder: dir);
  }
  final res = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    type: FileType.audio,
  );
  final paths = res?.files.map((f) => f.path).whereType<String>().toList();
  if (paths == null || paths.isEmpty) return null;
  return ImportSelection(files: paths);
}

Future<String?> askText(BuildContext context,
    {required String title, String? initial, String hint = ''}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 160, vertical: 60),
      child: Glass(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                      icon: Icons.check_rounded,
                      label: 'حفظ',
                      primary: true,
                      onTap: () => Navigator.pop(ctx, ctrl.text)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: GlassButton(
                      icon: Icons.close_rounded,
                      label: 'إلغاء',
                      onTap: () => Navigator.pop(ctx)),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
