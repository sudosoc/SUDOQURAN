import 'package:flutter/material.dart';

import '../data/reciters.dart';
import '../data/surahs.dart';
import '../services/library.dart';
import '../services/player.dart';
import '../services/settings.dart';
import '../services/sources.dart';
import 'glass.dart';
import 'photos_card.dart';

/// Quran section: reciter grid → surah grid (nested navigator keeps the
/// player panel and side rail in place).
class QuranSection extends StatefulWidget {
  const QuranSection({super.key});

  @override
  State<QuranSection> createState() => _QuranSectionState();
}

class _QuranSectionState extends State<QuranSection> {
  Reciter? _open;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _open == null
          ? ReciterGrid(key: const ValueKey('grid'), onOpen: (r) => setState(() => _open = r))
          : SurahGrid(
              key: ValueKey(_open!.id),
              reciter: _open!,
              onBack: () => setState(() => _open = null),
            ),
    );
  }
}

// ----------------------------------------------------------------------------
class ReciterGrid extends StatelessWidget {
  final ValueChanged<Reciter> onOpen;
  const ReciterGrid({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Library.instance, Settings.instance, Sources.instance]),
      builder: (context, _) {
        final last = Settings.instance.lastSession;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 18),
                child: Row(
                  children: [
                    const Text('القرآن الكريم',
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 14),
                    Text('${reciters.length} قارئ',
                        style: TextStyle(color: AppColors.muted, fontSize: 18)),
                    const Spacer(),
                    if (last != null && (last['title'] as String?)?.isNotEmpty == true)
                      _ContinueChip(last: last),
                  ],
                ),
              ),
            ),
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 330,
                mainAxisExtent: 128,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _ReciterCard(reciter: reciters[i], onTap: () => onOpen(reciters[i])),
                childCount: reciters.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        );
      },
    );
  }
}

class _ContinueChip extends StatelessWidget {
  final Map<String, dynamic> last;
  const _ContinueChip({required this.last});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: () => Player.instance.resumeLast(),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            color: AppColors.emerald.withOpacity(0.14),
            border: Border.all(color: AppColors.emerald.withOpacity(0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.play_circle_fill_rounded, color: AppColors.emerald, size: 30),
            const SizedBox(width: 10),
            Text('استكمال: ${last['title']}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('  ·  ${last['subtitle'] ?? ''}',
                style: TextStyle(fontSize: 16, color: AppColors.muted)),
          ]),
        ),
      ),
    );
  }
}

class _ReciterCard extends StatelessWidget {
  final Reciter reciter;
  final VoidCallback onTap;
  const _ReciterCard({required this.reciter, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lib = Library.instance;
    final local = lib.localSurahs(reciter).length;
    final avail = lib.available(reciter).length;
    final job = lib.jobs[reciter.id];
    final downloading = lib.isDownloading(reciter.id);
    final playingThis = Player.instance.reciterId == reciter.id &&
        Player.instance.kind == PlayKind.quran;

    final (statusIcon, statusText, statusColor) = downloading
        ? (Icons.downloading_rounded, 'جاري التحميل ${(job!.fraction * 100).round()}%', AppColors.teal)
        : avail > 0 && local >= avail
            ? (Icons.offline_pin_rounded, avail == 114 ? 'المصحف كامل أوفلاين' : '$local سورة أوفلاين', AppColors.emerald)
            : local > 0
                ? (Icons.download_done_rounded, '$local من $avail محملة', AppColors.emerald)
                : avail > 0
                    ? (Icons.cloud_outlined, '$avail سورة متاحة للتحميل', AppColors.muted)
                    : (Icons.hourglass_top_rounded, 'جاري البحث عن مصدر', AppColors.gold);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Glass(
          blur: false,
          radius: 26,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          borderColor: playingThis ? AppColors.gold : null,
          borderWidth: playingThis ? 2 : 1.2,
          child: Row(
            children: [
              ReciterAvatar(reciter.initials, photoId: reciter.id, size: 74, glow: playingThis),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reciter.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.2)),
                    if (reciter.subtitle.isNotEmpty)
                      Text(reciter.subtitle,
                          style: TextStyle(fontSize: 15, color: AppColors.gold)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(statusIcon, size: 18, color: statusColor),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(statusText,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, color: statusColor)),
                      ),
                    ]),
                    if (downloading)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: LinearProgressIndicator(
                          value: job!.fraction,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(4),
                          color: AppColors.teal,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
class SurahGrid extends StatelessWidget {
  final Reciter reciter;
  final VoidCallback onBack;
  const SurahGrid({super.key, required this.reciter, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final lib = Library.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([lib, Settings.instance, Player.instance, Sources.instance]),
      builder: (context, _) {
        final avail = lib.available(reciter);
        final local = lib.localSurahs(reciter);
        final job = lib.jobs[reciter.id];
        final downloading = lib.isDownloading(reciter.id);
        final stream = Settings.instance.allowStreaming;
        final p = Player.instance;
        final playingSurah = p.kind == PlayKind.quran && p.reciterId == reciter.id ? p.currentSurah : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Glass(
              radius: 26,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      GlassButton(icon: Icons.arrow_back_rounded, size: 60, onTap: onBack),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: () => pickPhotoFor(context, reciter.id),
                        child: ReciterAvatar(reciter.initials, photoId: reciter.id, size: 60),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(reciter.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                            Text(
                              downloading
                                  ? 'جاري التحميل: ${job!.done}/${job!.total}${job.failed > 0 ? ' (فشل ${job.failed})' : ''}'
                                  : avail.isEmpty
                                      ? 'لسه مفيش مصدر — المصادر بتتحدث تلقائيًا'
                                      : '${local.length} من ${avail.length} سورة على الجهاز${avail.length < 114 ? ' (المتاح أونلاين ${avail.length})' : ''}',
                              style: TextStyle(color: AppColors.muted, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      if (avail.isNotEmpty)
                        downloading
                            ? GlassButton(
                                icon: Icons.stop_rounded,
                                label: 'إيقاف',
                                size: 60,
                                onTap: () => lib.cancel(reciter.id))
                            : GlassButton(
                                icon: Icons.download_rounded,
                                label: lib.reciterComplete(reciter) ? 'تم التحميل' : 'تحميل الكل',
                                size: 60,
                                primary: !lib.reciterComplete(reciter),
                                onTap: lib.reciterComplete(reciter)
                                    ? null
                                    : () {
                                        lib.downloadReciter(reciter);
                                        toast(context, 'بدأ تحميل المصحف — تقدر تسمع عادي أثناء التحميل');
                                      },
                              ),
                      const SizedBox(width: 10),
                      if (local.isNotEmpty && !downloading)
                        GlassButton(
                          icon: Icons.delete_outline_rounded,
                          size: 60,
                          onTap: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: AppColors.bg1,
                                title: Text('حذف سور ${reciter.name} المحملة؟'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
                                ],
                              ),
                            );
                            if (ok == true) await lib.deleteReciter(reciter);
                          },
                        ),
                    ],
                  ),
                  if (downloading)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: LinearProgressIndicator(
                        value: job!.fraction,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(6),
                        color: AppColors.gold,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisExtent: 112,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: 114,
                itemBuilder: (context, i) {
                  final s = surahs[i];
                  final isLocal = local.contains(s.number);
                  final remote = avail.contains(s.number);
                  final playable = isLocal || (stream && remote);
                  return _SurahTile(
                    s: s,
                    isLocal: isLocal,
                    remote: remote,
                    playing: playingSurah == s.number,
                    onTap: () async {
                      if (playable) {
                        await Player.instance.playQuran(reciter, s.number);
                      } else if (remote) {
                        lib.downloadReciter(reciter, only: [s.number]);
                        if (context.mounted) toast(context, 'جاري تحميل سورة ${s.name}...');
                      } else if (context.mounted) {
                        toast(context, 'السورة دي لسه ملهاش مصدر أونلاين للقارئ ده');
                      }
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SurahTile extends StatelessWidget {
  final SurahInfo s;
  final bool isLocal;
  final bool remote;
  final bool playing;
  final VoidCallback onTap;
  const _SurahTile({
    required this.s,
    required this.isLocal,
    required this.remote,
    required this.playing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = isLocal
        ? Icons.offline_pin_rounded
        : remote
            ? Icons.cloud_outlined
            : Icons.block_rounded;
    final iconColor = isLocal ? AppColors.emerald : (remote ? AppColors.muted : Colors.white24);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Glass(
          blur: false,
          radius: 22,
          opacity: playing ? 0.2 : 0.08,
          borderColor: playing ? AppColors.gold : null,
          borderWidth: playing ? 2 : 1.2,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold.withOpacity(0.6), width: 1.5),
                    ),
                    child: Text('${s.number}',
                        style: TextStyle(
                            fontSize: 15, color: AppColors.gold, fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  playing
                      ? Icon(Icons.graphic_eq_rounded, color: AppColors.gold, size: 26)
                      : Icon(icon, color: iconColor, size: 22),
                ],
              ),
              const Spacer(),
              Text(s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              Text('${s.ayahs} آية · ${s.type}',
                  style: TextStyle(fontSize: 14, color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
