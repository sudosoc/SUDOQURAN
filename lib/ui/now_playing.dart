import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/player.dart';
import 'glass.dart';

/// Persistent player panel — on the driver's side of the screen.
class NowPlayingPanel extends StatelessWidget {
  const NowPlayingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final player = Player.instance;
    return Glass(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      child: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          final has = player.hasMedia;
          return LayoutBuilder(builder: (context, c) {
            final disc = (c.maxHeight * 0.30).clamp(90.0, 200.0).toDouble();
            return Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.graphic_eq_rounded, color: AppColors.emerald, size: 22),
                    const SizedBox(width: 8),
                    Text(has ? 'يُتلى الآن' : 'المشغل',
                        style: const TextStyle(color: AppColors.muted, fontSize: 17)),
                  ],
                ),
                const Spacer(),
                ReciterAvatar(player.artLetters ?? '۞', size: disc, glow: player.playing),
                const SizedBox(height: 18),
                Text(
                  has ? player.title : 'اختر قارئًا وسورة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  has ? player.subtitle : 'أو اضغط تشغيل لاستكمال آخر تلاوة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, color: AppColors.gold),
                ),
                const Spacer(),
                const _Progress(),
                const SizedBox(height: 10),
                Directionality(
                  // media controls stay left-to-right by convention
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GlassButton(
                          icon: Icons.skip_previous_rounded,
                          size: 66,
                          onTap: has ? player.previous : null),
                      GlassButton(
                          icon: Icons.replay_10_rounded,
                          size: 56,
                          onTap: has ? () => player.seekBy(-10) : null),
                      StreamBuilder<PlayerState>(
                        stream: player.audio.playerStateStream,
                        builder: (context, snap) {
                          final st = snap.data;
                          final loading = st?.processingState == ProcessingState.loading ||
                              st?.processingState == ProcessingState.buffering;
                          final playing = st?.playing ?? false;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              GlassButton(
                                icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                size: 92,
                                primary: true,
                                onTap: () async {
                                  if (player.hasMedia) {
                                    await player.toggle();
                                    return;
                                  }
                                  final ok = await player.resumeLast();
                                  if (!ok && context.mounted) {
                                    toast(context, 'لا توجد تلاوة سابقة — اختر قارئًا');
                                  }
                                },
                              ),
                              if (loading && playing)
                                const SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 3, color: AppColors.emerald),
                                ),
                            ],
                          );
                        },
                      ),
                      GlassButton(
                          icon: Icons.forward_10_rounded,
                          size: 56,
                          onTap: has ? () => player.seekBy(10) : null),
                      GlassButton(
                          icon: Icons.skip_next_rounded,
                          size: 66,
                          onTap: has ? player.next : null),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                StreamBuilder<LoopMode>(
                  stream: player.audio.loopModeStream,
                  builder: (context, snap) {
                    final mode = snap.data ?? LoopMode.off;
                    final (icon, label) = switch (mode) {
                      LoopMode.off => (Icons.repeat_rounded, 'بدون تكرار'),
                      LoopMode.all => (Icons.repeat_on_rounded, 'تكرار القائمة'),
                      LoopMode.one => (Icons.repeat_one_on_rounded, 'تكرار السورة'),
                    };
                    return GlassButton(
                      icon: icon,
                      label: label,
                      size: 54,
                      color: mode == LoopMode.off ? AppColors.muted : AppColors.emerald,
                      onTap: player.cycleLoop,
                    );
                  },
                ),
              ],
            );
          });
        },
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress();

  @override
  Widget build(BuildContext context) {
    final audio = Player.instance.audio;
    return StreamBuilder<Duration?>(
      stream: audio.durationStream,
      builder: (context, dSnap) {
        final dur = dSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: audio.positionStream,
          builder: (context, pSnap) {
            var pos = pSnap.data ?? Duration.zero;
            if (pos > dur) pos = dur;
            final max = dur.inMilliseconds.toDouble();
            return Column(
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: SliderTheme(
                    data: SliderTheme.of(context),
                    child: Slider(
                      min: 0,
                      max: max <= 0 ? 1 : max,
                      value: max <= 0 ? 0 : pos.inMilliseconds.toDouble().clamp(0.0, max).toDouble(),
                      onChanged: max <= 0
                          ? null
                          : (v) => audio.seek(Duration(milliseconds: v.round())),
                    ),
                  ),
                ),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(fmtDuration(pos),
                            style: const TextStyle(color: AppColors.muted, fontSize: 16)),
                        Text(fmtDuration(dur),
                            style: const TextStyle(color: AppColors.muted, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
