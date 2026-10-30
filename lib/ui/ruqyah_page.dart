import 'package:flutter/material.dart';

import '../data/ruqyah.dart';
import '../services/library.dart';
import '../services/player.dart';
import 'glass.dart';
import 'import_sheet.dart';

class RuqyahSection extends StatefulWidget {
  const RuqyahSection({super.key});

  @override
  State<RuqyahSection> createState() => _RuqyahSectionState();
}

class _RuqyahSectionState extends State<RuqyahSection> {
  RuqyahSheikh _sel = ruqyahSheikhs.first;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Library.instance, Player.instance]),
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 16),
              child: Text('الرقية الشرعية',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
            ),
            SizedBox(
              height: 104,
              child: Row(
                children: [
                  for (final s in ruqyahSheikhs) ...[
                    Expanded(child: _SheikhCard(
                      sheikh: s,
                      selected: s.id == _sel.id,
                      onTap: () => setState(() => _sel = s),
                    )),
                    if (s != ruqyahSheikhs.last) const SizedBox(width: 16),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _SheikhBody(key: ValueKey(_sel.id), sheikh: _sel)),
          ],
        );
      },
    );
  }
}

class _SheikhCard extends StatelessWidget {
  final RuqyahSheikh sheikh;
  final bool selected;
  final VoidCallback onTap;
  const _SheikhCard({required this.sheikh, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Player.instance;
    final playing = p.sheikhId == sheikh.id &&
        (p.kind == PlayKind.ruqyahAyat || p.kind == PlayKind.ruqyahTracks);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Glass(
          blur: false,
          radius: 26,
          opacity: selected ? 0.2 : 0.07,
          borderColor: selected ? AppColors.gold : null,
          borderWidth: selected ? 2 : 1.2,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.shield_moon_rounded, color: AppColors.gold, size: 44),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الشيخ ${sheikh.name}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    Text(playing ? 'قيد التشغيل' : 'الرقية الشرعية',
                        style: TextStyle(
                            fontSize: 16,
                            color: playing ? AppColors.emerald : AppColors.muted)),
                  ],
                ),
              ),
              if (playing) const Icon(Icons.graphic_eq_rounded, color: AppColors.emerald, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheikhBody extends StatelessWidget {
  final RuqyahSheikh sheikh;
  const _SheikhBody({super.key, required this.sheikh});

  Future<void> _import(BuildContext context) async {
    final sel = await pickImportSource(context,
        hint: 'اختار ملفات رقية الشيخ ${sheikh.name} من الفلاشة أو الكارت — هتتنسخ جوه التطبيق وتشتغل أوفلاين.');
    if (sel == null) return;
    final n = await Library.instance
        .importToRuqyah(sheikh, folder: sel.folder, files: sel.files);
    if (context.mounted) toast(context, 'تم استيراد $n ملف');
  }

  Future<void> _fromUrl(BuildContext context) async {
    final url = await askText(context,
        title: 'تحميل رقية من رابط مباشر', hint: 'https://.../ruqyah.mp3');
    if (url == null || url.trim().isEmpty) return;
    final job = Library.instance.downloadRuqyahUrl(sheikh, url);
    if (context.mounted) toast(context, 'جاري التحميل...');
    final res = await job;
    if (context.mounted) {
      toast(context, res == null || res.failed > 0 ? 'فشل التحميل — اتأكد من الرابط' : 'تم التحميل ✓');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lib = Library.instance;
    final tracks = lib.ruqyahTracks(sheikh);
    final p = Player.instance;
    final ayatFiles = sheikh.everyAyahFolder != null ? lib.ruqyahAyatFiles(sheikh) : const [];
    final ayatKey = 'ruqyah_${sheikh.id}';
    final ayatJob = lib.jobs[ayatKey];
    final ayatDownloading = lib.isDownloading(ayatKey);
    final total = ruqyahAyatCount;

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        if (sheikh.everyAyahFolder != null)
          Glass(
            radius: 26,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: AppColors.gold, size: 32),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('الرقية الشرعية بآيات القرآن',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    ),
                    if (ayatFiles.isNotEmpty)
                      GlassButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'تشغيل',
                        size: 62,
                        primary: true,
                        onTap: () => p.playRuqyahAyat(sheikh),
                      ),
                    const SizedBox(width: 10),
                    if (ayatFiles.length < total)
                      ayatDownloading
                          ? GlassButton(
                              icon: Icons.stop_rounded,
                              label: 'إيقاف',
                              size: 62,
                              onTap: () => lib.cancel(ayatKey))
                          : GlassButton(
                              icon: Icons.download_rounded,
                              label: ayatFiles.isEmpty ? 'تحميل الرقية' : 'استكمال التحميل',
                              size: 62,
                              primary: ayatFiles.isEmpty,
                              onTap: () => lib.downloadRuqyahAyat(sheikh),
                            ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ayatDownloading
                      ? 'جاري التحميل ${ayatJob!.done}/${ayatJob!.total}'
                      : ayatFiles.length >= total
                          ? '$total آية بصوت الشيخ ${sheikh.name} — جاهزة أوفلاين'
                          : '${ayatFiles.length} من $total آية على الجهاز (حوالي 25 ميجا)',
                  style: const TextStyle(color: AppColors.muted, fontSize: 17),
                ),
                if (ayatDownloading)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: LinearProgressIndicator(
                      value: ayatJob!.fraction,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(6),
                      color: AppColors.gold,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final label in {for (final r in ruqyahAyat) r.label})
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: Colors.white.withOpacity(0.06),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Text(label, style: const TextStyle(fontSize: 16)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (sheikh.everyAyahFolder != null) const SizedBox(height: 16),
        Glass(
          radius: 26,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.queue_music_rounded, color: AppColors.gold, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        sheikh.everyAyahFolder != null ? 'تسجيلات رقية إضافية' : 'تسجيلات الرقية',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  ),
                  if (tracks.isNotEmpty)
                    GlassButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'تشغيل الكل',
                        size: 62,
                        primary: true,
                        onTap: () => p.playRuqyahTracks(sheikh)),
                  const SizedBox(width: 10),
                  GlassButton(
                      icon: Icons.usb_rounded,
                      label: 'استيراد',
                      size: 62,
                      onTap: () => _import(context)),
                  const SizedBox(width: 10),
                  GlassButton(
                      icon: Icons.link_rounded, size: 62, onTap: () => _fromUrl(context)),
                ],
              ),
              const SizedBox(height: 10),
              if (tracks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'مفيش تسجيلات لسه. حط ملفات رقية الشيخ ${sheikh.name} (mp3) على فلاشة، '
                    'ادخل "استيراد" واختار المجلد — أو حمّلها من رابط مباشر 🔗',
                    style: const TextStyle(color: AppColors.muted, fontSize: 18, height: 1.6),
                  ),
                ),
              for (var i = 0; i < tracks.length; i++)
                _TrackRow(
                  title: Player.trackTitle(tracks[i]),
                  index: i,
                  playing: p.kind == PlayKind.ruqyahTracks &&
                      p.sheikhId == sheikh.id &&
                      p.audio.currentIndex == i,
                  onPlay: () => p.playRuqyahTracks(sheikh, index: i),
                  onDelete: () => lib.deleteRuqyahTrack(tracks[i]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackRow extends StatelessWidget {
  final String title;
  final int index;
  final bool playing;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  const _TrackRow({
    required this.title,
    required this.index,
    required this.playing,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPlay,
          onLongPress: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.bg1,
                title: const Text('حذف التسجيل؟'),
                content: Text(title),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
                ],
              ),
            );
            if (ok == true) onDelete();
          },
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withOpacity(playing ? 0.14 : 0.05),
              border: Border.all(
                  color: playing ? AppColors.gold : Colors.white.withOpacity(0.10),
                  width: playing ? 2 : 1),
            ),
            child: Row(
              children: [
                Icon(playing ? Icons.graphic_eq_rounded : Icons.play_circle_outline_rounded,
                    color: playing ? AppColors.gold : AppColors.muted, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
