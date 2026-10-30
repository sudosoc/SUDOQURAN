import 'package:flutter/material.dart';

import '../data/owners.dart';
import '../data/reciters.dart';
import '../data/ruqyah.dart';
import '../services/library.dart';
import '../services/sources.dart';
import 'glass.dart';

/// Download manager: everything / all Quran / one reciter / ruqyah / azkar.
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  Future<int>? _used;

  @override
  void initState() {
    super.initState();
    _used = Library.instance.usedBytes();
  }

  Future<bool> _confirm(BuildContext context, String what) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bg1,
          title: Text('حذف $what من الجهاز؟'),
          content: const Text('هتقدر تحمله تاني في أي وقت.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
          ],
        ),
      ) ==
      true;

  @override
  Widget build(BuildContext context) {
    final lib = Library.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([lib, Sources.instance]),
      builder: (context, _) {
        final active = lib.jobs.values.where((j) => !j.finished).toList();
        final quranAvail = reciters.fold<int>(0, (a, r) => a + lib.available(r).length);
        final quranLocal =
            reciters.fold<int>(0, (a, r) => a + lib.localSurahs(r).intersection(lib.available(r)).length);
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // ---------------------------------------------------- status
            Glass(
              radius: 26,
              padding: const EdgeInsets.all(20),
              borderColor: lib.everythingRunning || active.isNotEmpty ? AppColors.gold.withOpacity(0.6) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storage_rounded, color: AppColors.gold, size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FutureBuilder<int>(
                              future: _used,
                              builder: (context, snap) => Text(
                                'على الجهاز: ${snap.hasData ? formatBytes(snap.data!) : '...'}',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                              ),
                            ),
                            Text('القرآن: $quranLocal من $quranAvail سورة متاحة',
                                style: TextStyle(color: AppColors.muted, fontSize: 16)),
                          ],
                        ),
                      ),
                      GlassButton(
                          icon: Icons.refresh_rounded,
                          size: 54,
                          onTap: () => setState(() => _used = lib.usedBytes())),
                      if (lib.everythingRunning || active.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        GlassButton(
                            icon: Icons.stop_rounded,
                            label: 'إيقاف الكل',
                            size: 58,
                            onTap: lib.stopEverything),
                      ],
                    ],
                  ),
                  if (lib.everythingRunning || active.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    if (lib.everythingCurrent != null)
                      Text('في الطابور دلوقتي: ${lib.everythingCurrent}',
                          style: TextStyle(color: AppColors.gold, fontSize: 17)),
                    for (final j in active)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            SizedBox(
                                width: 230,
                                child: Text(_jobLabel(j.key),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 17))),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: j.fraction,
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(7),
                                color: AppColors.emerald,
                                backgroundColor: Colors.white12,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('${j.done}/${j.total}', style: TextStyle(color: AppColors.muted, fontSize: 16)),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            // ---------------------------------------------- quick actions
            const _Header('تحميل سريع'),
            LayoutBuilder(builder: (context, c) {
              final w = (c.maxWidth - 3 * 14) / 4;
              final busy = lib.everythingRunning;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _Action(
                      width: w,
                      icon: Icons.all_inclusive_rounded,
                      title: 'كل حاجة',
                      sub: 'القرآن + الرقية + الأذكار',
                      onTap: busy ? null : lib.downloadEverything),
                  _Action(
                      width: w,
                      icon: Icons.menu_book_rounded,
                      title: 'القرآن لكل الشيوخ',
                      sub: '${reciters.length} قارئ',
                      onTap: busy ? null : lib.downloadAllQuran),
                  _Action(
                      width: w,
                      icon: Icons.shield_moon_rounded,
                      title: 'كل الرقية',
                      sub: '${ruqyahSheikhs.length} شيوخ',
                      onTap: busy ? null : lib.downloadAllRuqyah),
                  _Action(
                      width: w,
                      icon: Icons.wb_twilight_rounded,
                      title: 'كل الأذكار',
                      sub: 'الصباح والمساء',
                      onTap: busy || lib.azkarOwners.isEmpty ? null : lib.downloadAllAzkar),
                ],
              );
            }),
            const SizedBox(height: 22),
            // ------------------------------------------------- per reciter
            const _Header('مصحف شيخ معين'),
            for (final r in reciters)
              _Row(
                photoId: r.id,
                initials: r.initials,
                title: r.name,
                total: lib.available(r).length,
                local: lib.localSurahs(r).intersection(lib.available(r)).length,
                unit: 'سورة',
                downloading: lib.isDownloading(r.id),
                fraction: lib.jobs[r.id]?.fraction,
                onDownload: () => lib.downloadReciter(r),
                onStop: () => lib.cancel(r.id),
                onDelete: () async {
                  if (await _confirm(context, 'مصحف ${r.name}')) {
                    await lib.deleteReciter(r);
                    setState(() => _used = lib.usedBytes());
                  }
                },
              ),
            const SizedBox(height: 22),
            // ------------------------------------------------------ ruqyah
            const _Header('الرقية الشرعية'),
            for (final s in ruqyahSheikhs)
              Builder(builder: (context) {
                final tracks = Sources.instance.ruqyahTracks(s.id);
                final ayat = s.everyAyahFolder != null;
                final total = tracks.length + (ayat ? ruqyahAyatCount : 0);
                final local = tracks.where((t) => lib.localTrack(s, t) != null).length +
                    (ayat ? lib.ruqyahAyatFiles(s).length : 0);
                final keys = [lib.tracksKey(s), if (ayat) lib.ayatKey(s)];
                final dl = keys.any(lib.isDownloading);
                return _Row(
                  photoId: s.id,
                  initials: ownerInitials(s.id),
                  title: 'رقية الشيخ ${s.name}',
                  total: total,
                  local: local,
                  unit: 'ملف',
                  downloading: dl,
                  fraction: dl ? lib.jobs[keys.firstWhere(lib.isDownloading)]?.fraction : null,
                  onDownload: () async {
                    if (ayat) await lib.downloadRuqyahAyat(s);
                    await lib.downloadRuqyahTracks(s);
                  },
                  onStop: () => keys.forEach(lib.cancel),
                  onDelete: () async {
                    if (await _confirm(context, 'رقية ${s.name}')) {
                      await lib.deleteDir(lib.ruqyahTracksDir(s));
                      await lib.deleteDir(lib.ruqyahAyatDir(s));
                      setState(() => _used = lib.usedBytes());
                    }
                  },
                );
              }),
            const SizedBox(height: 22),
            // ------------------------------------------------------- azkar
            const _Header('أذكار الصباح والمساء'),
            if (lib.azkarOwners.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('لسه مفيش أذكار متاحة في المصادر.',
                    style: TextStyle(color: AppColors.muted, fontSize: 17)),
              ),
            for (final id in lib.azkarOwners)
              Builder(builder: (context) {
                final all = {
                  for (final t in [
                    ...Sources.instance.azkarTracks(id, 'morning'),
                    ...Sources.instance.azkarTracks(id, 'evening'),
                  ])
                    t.url: t
                }.values.toList();
                final dir = lib.azkarDir(id);
                return _Row(
                  photoId: id,
                  initials: ownerInitials(id),
                  title: 'أذكار — ${ownerName(id)}',
                  total: all.length,
                  local: all.where((t) => lib.localIn(dir, t) != null).length,
                  unit: 'ملف',
                  downloading: lib.isDownloading(lib.azkarKey(id)),
                  fraction: lib.jobs[lib.azkarKey(id)]?.fraction,
                  onDownload: () => lib.downloadAzkar(id),
                  onStop: () => lib.cancel(lib.azkarKey(id)),
                  onDelete: () async {
                    if (await _confirm(context, 'أذكار ${ownerName(id)}')) {
                      await lib.deleteDir(dir);
                      setState(() => _used = lib.usedBytes());
                    }
                  },
                );
              }),
          ],
        );
      },
    );
  }

  String _jobLabel(String key) {
    if (key.startsWith('ayat_')) return 'آيات الرقية — ${ownerName(key.substring(5))}';
    if (key.startsWith('tracks_')) return 'رقية — ${ownerName(key.substring(7))}';
    if (key.startsWith('azkar_')) return 'أذكار — ${ownerName(key.substring(6))}';
    return 'مصحف ${ownerName(key)}';
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
        child: Row(children: [
          Container(width: 5, height: 26, decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _Action extends StatelessWidget {
  final double width;
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback? onTap;
  const _Action({required this.width, required this.icon, required this.title, required this.sub, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width < 200 ? 200 : width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Glass(
            blur: false,
            radius: 24,
            padding: const EdgeInsets.all(18),
            opacity: onTap == null ? 0.04 : 0.1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 38, color: onTap == null ? Colors.white24 : AppColors.gold),
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                Text(sub, style: TextStyle(fontSize: 15, color: AppColors.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String photoId;
  final String initials;
  final String title;
  final int total;
  final int local;
  final String unit;
  final bool downloading;
  final double? fraction;
  final VoidCallback onDownload;
  final VoidCallback onStop;
  final VoidCallback onDelete;
  const _Row({
    required this.photoId,
    required this.initials,
    required this.title,
    required this.total,
    required this.local,
    required this.unit,
    required this.downloading,
    required this.fraction,
    required this.onDownload,
    required this.onStop,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final done = total > 0 && local >= total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Glass(
        blur: false,
        radius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            ReciterAvatar(initials, photoId: photoId, size: 54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : (downloading ? fraction : local / total),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(6),
                          color: done ? AppColors.emerald : AppColors.gold,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(total == 0 ? 'مفيش مصدر' : '$local/$total $unit',
                          style: TextStyle(fontSize: 15, color: AppColors.muted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            if (downloading)
              GlassButton(icon: Icons.stop_rounded, size: 52, onTap: onStop)
            else if (!done && total > 0)
              GlassButton(icon: Icons.download_rounded, size: 52, onTap: onDownload)
            else if (done)
              Icon(Icons.offline_pin_rounded, color: AppColors.emerald, size: 34),
            const SizedBox(width: 8),
            GlassButton(
                icon: Icons.delete_outline_rounded,
                size: 52,
                onTap: local > 0 && !downloading ? onDelete : null),
          ],
        ),
      ),
    );
  }
}
