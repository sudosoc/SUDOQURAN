import 'package:flutter/material.dart';

import '../data/owners.dart';
import '../data/ruqyah.dart';
import '../services/library.dart';
import '../services/player.dart';
import '../services/settings.dart';
import '../services/sources.dart';
import 'azkar_view.dart';
import 'glass.dart';

class RuqyahSection extends StatefulWidget {
  const RuqyahSection({super.key});

  @override
  State<RuqyahSection> createState() => _RuqyahSectionState();
}

class _RuqyahSectionState extends State<RuqyahSection> {
  static RuqyahSheikh _sel = ruqyahSheikhs.first;
  static int _mode = 0; // 0 = ruqyah, 1 = azkar

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Library.instance, Player.instance, Sources.instance, Settings.instance]),
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
              child: Row(
                children: [
                  for (final (i, label, icon) in const [
                    (0, 'الرقية الشرعية', Icons.shield_moon_rounded),
                    (1, 'أذكار الصباح والمساء', Icons.wb_twilight_rounded),
                  ]) ...[
                    _Segment(
                      label: label,
                      icon: icon,
                      selected: _mode == i,
                      onTap: () => setState(() => _mode = i),
                    ),
                    const SizedBox(width: 12),
                  ],
                ],
              ),
            ),
            if (_mode == 1) const Expanded(child: AzkarView()),
            if (_mode == 0) ...[
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
          ],
        );
      },
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _Segment({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            color: selected ? AppColors.gold.withOpacity(0.2) : Colors.white.withOpacity(0.05),
            border: Border.all(color: selected ? AppColors.gold : Colors.white.withOpacity(0.12), width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: selected ? AppColors.gold : AppColors.muted, size: 28),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                    color: selected ? AppColors.text : AppColors.muted)),
          ]),
        ),
      ),
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
              ReciterAvatar(ownerInitials(sheikh.id), photoId: sheikh.id, size: 72, glow: playing),
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
              if (playing) Icon(Icons.graphic_eq_rounded, color: AppColors.emerald, size: 30),
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

  @override
  Widget build(BuildContext context) {
    final lib = Library.instance;
    final tracks = Sources.instance.ruqyahTracks(sheikh.id);
    final localCount = tracks.where((t) => lib.localTrack(sheikh, t) != null).length;
    final tKey = lib.tracksKey(sheikh);
    final tJob = lib.jobs[tKey];
    final tDownloading = lib.isDownloading(tKey);
    final stream = Settings.instance.allowStreaming;
    final p = Player.instance;
    final ayatFiles = sheikh.everyAyahFolder != null ? lib.ruqyahAyatFiles(sheikh) : const [];
    final ayatKey = lib.ayatKey(sheikh);
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
                    Icon(Icons.auto_awesome_rounded, color: AppColors.gold, size: 32),
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
                  style: TextStyle(color: AppColors.muted, fontSize: 17),
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
                  Icon(Icons.queue_music_rounded, color: AppColors.gold, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        sheikh.everyAyahFolder != null ? 'تسجيلات رقية إضافية' : 'تسجيلات الرقية',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  ),
                  if (tracks.isNotEmpty && (localCount > 0 || stream))
                    GlassButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'تشغيل الكل',
                        size: 62,
                        primary: true,
                        onTap: () => p.playRuqyahTracks(sheikh)),
                  const SizedBox(width: 10),
                  if (tracks.isNotEmpty && localCount < tracks.length)
                    tDownloading
                        ? GlassButton(
                            icon: Icons.stop_rounded,
                            label: 'إيقاف',
                            size: 62,
                            onTap: () => lib.cancel(tKey))
                        : GlassButton(
                            icon: Icons.download_rounded,
                            label: 'تحميل',
                            size: 62,
                            onTap: () => lib.downloadRuqyahTracks(sheikh)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                tDownloading
                    ? 'جاري التحميل ${tJob!.done}/${tJob!.total}'
                    : '$localCount من ${tracks.length} تسجيل على الجهاز',
                style: TextStyle(color: AppColors.muted, fontSize: 17),
              ),
              if (tDownloading)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: LinearProgressIndicator(
                    value: tJob!.fraction,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(6),
                    color: AppColors.gold,
                    backgroundColor: Colors.white12,
                  ),
                ),
              const SizedBox(height: 10),
              if (tracks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    Sources.instance.refreshing
                        ? 'بندوّر على التسجيلات...'
                        : 'لسه ملقيناش تسجيلات أونلاين للشيخ ${sheikh.name} — قائمة المصادر بتتحدث تلقائيًا كل أسبوع.',
                    style: TextStyle(color: AppColors.muted, fontSize: 18, height: 1.6),
                  ),
                ),
              for (var i = 0; i < tracks.length; i++)
                _TrackRow(
                  title: tracks[i].title,
                  index: i,
                  local: lib.localTrack(sheikh, tracks[i]) != null,
                  playing: p.kind == PlayKind.ruqyahTracks &&
                      p.sheikhId == sheikh.id &&
                      p.title == tracks[i].title,
                  onPlay: () async {
                    final ok = await p.playRuqyahTracks(sheikh, index: i);
                    if (!ok && context.mounted) toast(context, 'حمّل التسجيل الأول أو شغّل الأونلاين من الإعدادات');
                  },
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
  final bool local;
  final VoidCallback onPlay;
  const _TrackRow({
    required this.title,
    required this.index,
    required this.playing,
    required this.local,
    required this.onPlay,
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
                Icon(local ? Icons.offline_pin_rounded : Icons.cloud_outlined,
                    color: local ? AppColors.emerald : AppColors.muted, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
