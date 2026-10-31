import 'package:flutter/material.dart';

import '../data/reciters.dart';
import '../data/surahs.dart';
import '../services/library.dart';
import '../services/player.dart';
import '../services/prayer.dart';
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

  static const _quick = [(18, 'الكهف'), (36, 'يس'), (67, 'الملك'), (55, 'الرحمن'), (56, 'الواقعة'), (2, 'البقرة')];

  /// Reciter for the quick surah chips: last one used, else first that has audio.
  static Reciter _defaultReciter() {
    final last = reciterById(Settings.instance.lastSession?['reciter'] as String?);
    if (last != null) return last;
    return reciters.firstWhere((r) => Library.instance.available(r).isNotEmpty, orElse: () => reciters[2]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Library.instance, Settings.instance, Sources.instance, Player.instance, Prayer.instance]),
      builder: (context, _) {
        final last = Settings.instance.lastSession;
        final hour = DateTime.now().hour;
        final greet = hour < 12 ? 'صباح الخير' : (hour < 18 ? 'مساء النور' : 'مساء الخير');
        final def = _defaultReciter();
        final offline = reciters.where((r) => Library.instance.reciterComplete(r)).length;
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ------------------------------------------------------- header
            SliverToBoxAdapter(
              child: _Appear(
                index: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(greet, style: TextStyle(color: AppColors.gold, fontSize: 20)),
                          const Text('القرآن الكريم', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, height: 1.1)),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            if (Settings.instance.prayerEnabled)
                              _StatPill(
                                icon: Icons.mosque_rounded,
                                text: '${Prayer.instance.next.$1} ${fmtClock(Prayer.instance.next.$2, h24: Settings.instance.clock24)}'
                                    ' · بعد ${fmtCountdown(Prayer.instance.next.$2.difference(DateTime.now()))}',
                              ),
                            _StatPill(icon: Icons.record_voice_over_rounded, text: '${reciters.length} قارئ'),
                            _StatPill(icon: Icons.offline_pin_rounded, text: '$offline أوفلاين'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ---------------------------------------------- continue hero
            if (last != null && (last['title'] as String?)?.isNotEmpty == true)
              SliverToBoxAdapter(child: _Appear(index: 1, child: _ContinueHero(last: last))),
            // ------------------------------------------------- quick chips
            SliverToBoxAdapter(
              child: _Appear(
                index: 2,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 22),
                  child: SizedBox(
                    height: 62,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        for (final (n, name) in _quick)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 12),
                            child: _QuickChip(
                              label: 'سورة $name',
                              onTap: () async {
                                final ok = await Player.instance.playQuran(def, n);
                                if (!ok && context.mounted) {
                                  toast(context, 'حمّل سورة $name لـ ${def.name} الأول أو فعّل التشغيل أونلاين');
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _Appear(
                index: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
                  child: Row(children: [
                    Container(
                        width: 5,
                        height: 26,
                        decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 10),
                    const Text('القرّاء', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 10),
                    Text('اختار الشيخ وبعدين السورة', style: TextStyle(color: AppColors.muted, fontSize: 16)),
                  ]),
                ),
              ),
            ),
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 340,
                mainAxisExtent: 132,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _Appear(
                  index: 4 + i,
                  child: _ReciterCard(reciter: reciters[i], onTap: () => onOpen(reciters[i])),
                ),
                childCount: reciters.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }
}

/// Staggered fade + rise on first build.
class _Appear extends StatelessWidget {
  final int index;
  final Widget child;
  const _Appear({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + 45 * index.clamp(0, 14)),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _StatPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 20, color: AppColors.gold),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 16)),
        ]),
      );
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              gradient: LinearGradient(colors: [
                AppColors.gold.withOpacity(0.22),
                AppColors.emerald.withOpacity(0.10),
              ]),
              border: Border.all(color: AppColors.gold.withOpacity(0.45)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.play_circle_fill_rounded, color: AppColors.gold, size: 28),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

class _ContinueHero extends StatelessWidget {
  final Map<String, dynamic> last;
  const _ContinueHero({required this.last});

  @override
  Widget build(BuildContext context) {
    final p = Player.instance;
    final isCurrent = p.hasMedia && p.title == last['title'];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => isCurrent ? p.toggle() : p.resumeLast(),
        child: Glass(
          radius: 30,
          padding: const EdgeInsets.all(18),
          borderColor: AppColors.gold.withOpacity(0.5),
          child: Row(
            children: [
              ReciterAvatar('', photoId: last['reciter'] as String? ?? last['sheikh'] as String?, size: 96, glow: isCurrent && p.playing),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isCurrent && p.playing ? 'يُتلى الآن' : 'كمّل من حيث توقفت',
                        style: TextStyle(color: AppColors.gold, fontSize: 17)),
                    Text('${last['title']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                    Text('${last['subtitle'] ?? ''}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, color: AppColors.muted)),
                  ],
                ),
              ),
              GlassButton(
                icon: isCurrent && p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 84,
                primary: true,
                onTap: () => isCurrent ? p.toggle() : p.resumeLast(),
              ),
            ],
          ),
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
