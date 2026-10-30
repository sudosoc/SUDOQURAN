import 'package:flutter/material.dart';

import '../data/owners.dart';
import '../services/library.dart';
import '../services/player.dart';
import '../services/settings.dart';
import '../services/sources.dart';
import 'glass.dart';

/// Morning & evening azkar in the voices that are available online.
class AzkarView extends StatefulWidget {
  const AzkarView({super.key});

  @override
  State<AzkarView> createState() => _AzkarViewState();
}

class _AzkarViewState extends State<AzkarView> {
  // Morning until 3 PM, evening after — like the sunnah timings, roughly.
  String _when = DateTime.now().hour < 15 ? 'morning' : 'evening';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Library.instance, Sources.instance, Player.instance, Settings.instance]),
      builder: (context, _) {
        final lib = Library.instance;
        final owners = Sources.instance.azkarOwners(_when);
        final p = Player.instance;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (final w in const ['morning', 'evening']) ...[
                  Expanded(
                    child: _TimeCard(
                      morning: w == 'morning',
                      selected: _when == w,
                      onTap: () => setState(() => _when = w),
                    ),
                  ),
                  if (w == 'morning') const SizedBox(width: 16),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: owners.isEmpty
                  ? Center(
                      child: Text(
                        Sources.instance.refreshing
                            ? 'بندوّر على تسجيلات الأذكار...'
                            : 'لسه مفيش تسجيلات أذكار متاحة — قايمة المصادر بتتحدث لوحدها كل أسبوع.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, fontSize: 19),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 420,
                        mainAxisExtent: 132,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: owners.length,
                      itemBuilder: (context, i) {
                        final id = owners[i];
                        final tracks = Sources.instance.azkarTracks(id, _when);
                        final dir = lib.azkarDir(id);
                        final local = tracks.where((t) => lib.localIn(dir, t) != null).length;
                        final key = lib.azkarKey(id);
                        final downloading = lib.isDownloading(key);
                        final playing = p.kind == PlayKind.azkar && p.azkarOwner == id && p.azkarWhen == _when;
                        return Glass(
                          blur: false,
                          radius: 26,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          borderColor: playing ? AppColors.gold : null,
                          borderWidth: playing ? 2 : 1.2,
                          child: Row(
                            children: [
                              ReciterAvatar(ownerInitials(id), photoId: id, size: 78, glow: playing),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(ownerName(id),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      Icon(local == tracks.length ? Icons.offline_pin_rounded : Icons.cloud_outlined,
                                          size: 18,
                                          color: local == tracks.length ? AppColors.emerald : AppColors.muted),
                                      const SizedBox(width: 6),
                                      Text(
                                          downloading
                                              ? 'جاري التحميل ${(lib.jobs[key]!.fraction * 100).round()}%'
                                              : local == tracks.length
                                                  ? 'جاهزة أوفلاين'
                                                  : '${tracks.length} تسجيل · $local على الجهاز',
                                          style: TextStyle(fontSize: 15, color: AppColors.muted)),
                                    ]),
                                  ],
                                ),
                              ),
                              if (local < tracks.length && !downloading)
                                GlassButton(
                                    icon: Icons.download_rounded,
                                    size: 58,
                                    onTap: () => lib.downloadAzkar(id)),
                              const SizedBox(width: 10),
                              GlassButton(
                                icon: playing && p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                size: 64,
                                primary: true,
                                onTap: () async {
                                  if (playing) {
                                    await p.toggle();
                                    return;
                                  }
                                  final ok = await p.playAzkar(id, ownerName(id), _when);
                                  if (!ok && context.mounted) {
                                    toast(context, 'حمّل الأذكار الأول أو فعّل التشغيل أونلاين');
                                  }
                                },
                              ),
                            ],
                          ),
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

class _TimeCard extends StatelessWidget {
  final bool morning;
  final bool selected;
  final VoidCallback onTap;
  const _TimeCard({required this.morning, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(morning ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                  color: AppColors.gold, size: 40),
              const SizedBox(width: 14),
              Text(morning ? 'أذكار الصباح' : 'أذكار المساء',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}
