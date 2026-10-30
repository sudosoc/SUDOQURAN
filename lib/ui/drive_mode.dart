import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/library.dart';
import '../services/player.dart';
import 'glass.dart';

/// Full-screen, glance-friendly player for when the car is moving.
/// Swipe left/right = next/previous, double-tap anywhere = play/pause.
class DriveMode extends StatefulWidget {
  const DriveMode({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        PageRouteBuilder(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, __, ___) => const DriveMode(),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        ),
      );

  @override
  State<DriveMode> createState() => _DriveModeState();
}

class _DriveModeState extends State<DriveMode> {
  late Timer _clock;
  DateTime _now = DateTime.now();
  String? _flash; // short on-screen feedback after a gesture

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 15), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  void _show(String s) {
    setState(() => _flash = s);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted && _flash == s) setState(() => _flash = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Player.instance;
    final hh = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final mm = _now.minute.toString().padLeft(2, '0');
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () {
                final was = p.playing;
                p.toggle();
                _show(was ? '⏸' : '▶');
              },
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v.abs() < 250) return;
                if (v < 0) {
                  p.next();
                  _show('⏭');
                } else {
                  p.previous();
                  _show('⏮');
                }
              },
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: ListenableBuilder(
                    listenable: Listenable.merge([p, Library.instance]),
                    builder: (context, _) => Column(
                      children: [
                        Row(
                          children: [
                            GlassButton(
                              icon: Icons.close_rounded,
                              label: 'خروج',
                              size: 72,
                              onTap: () => Navigator.of(context).pop(),
                            ),
                            const Spacer(),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text('$hh:$mm',
                                  style: TextStyle(
                                      fontSize: 46, fontWeight: FontWeight.w300, color: AppColors.text)),
                            ),
                            const Spacer(),
                            Icon(Icons.directions_car_rounded, color: AppColors.gold, size: 40),
                            const SizedBox(width: 10),
                            Text('وضع السواقة',
                                style: TextStyle(fontSize: 24, color: AppColors.gold, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            ReciterAvatar(
                              p.artLetters ?? '۞',
                              photoId: p.reciterId ?? p.sheikhId ?? p.azkarOwner,
                              size: 210,
                              glow: p.playing,
                            ),
                            const SizedBox(width: 40),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.hasMedia ? p.title : 'اضغط تشغيل',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, height: 1.2),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    p.hasMedia ? p.subtitle : 'هيكمّل من آخر مكان وقفت عنده',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 30, color: AppColors.gold),
                                  ),
                                  const SizedBox(height: 26),
                                  const _ThickProgress(),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GlassButton(icon: Icons.skip_previous_rounded, size: 130, onTap: p.previous),
                              const SizedBox(width: 50),
                              StreamBuilder<PlayerState>(
                                stream: p.audio.playerStateStream,
                                builder: (context, snap) => GlassButton(
                                  icon: (snap.data?.playing ?? false)
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 190,
                                  primary: true,
                                  onTap: p.toggle,
                                ),
                              ),
                              const SizedBox(width: 50),
                              GlassButton(icon: Icons.skip_next_rounded, size: 130, onTap: p.next),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text('اسحب يمين أو شمال للسورة اللي بعدها · دوس مرتين في أي حتة للإيقاف',
                            style: TextStyle(color: AppColors.muted, fontSize: 18)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_flash != null)
            IgnorePointer(
              child: Center(
                child: Glass(
                  radius: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 30),
                  child: Text(_flash!, style: const TextStyle(fontSize: 90)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThickProgress extends StatelessWidget {
  const _ThickProgress();

  @override
  Widget build(BuildContext context) {
    final audio = Player.instance.audio;
    return StreamBuilder<Duration>(
      stream: audio.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = audio.duration ?? Duration.zero;
        final f = dur.inMilliseconds <= 0
            ? 0.0
            : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0).toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: LinearProgressIndicator(
                value: f,
                minHeight: 14,
                borderRadius: BorderRadius.circular(14),
                color: AppColors.gold,
                backgroundColor: Colors.white12,
              ),
            ),
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(fmtDuration(pos), style: TextStyle(fontSize: 22, color: AppColors.muted)),
                  Text(fmtDuration(dur), style: TextStyle(fontSize: 22, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
