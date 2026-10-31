import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/player.dart';
import '../services/sources.dart';
import 'glass.dart';

/// Live Quran radios: Cairo, Makkah, Madinah + one radio per reciter.
class RadioSection extends StatefulWidget {
  const RadioSection({super.key});

  @override
  State<RadioSection> createState() => _RadioSectionState();
}

class _RadioSectionState extends State<RadioSection> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Sources.instance, Player.instance]),
      builder: (context, _) {
        final main = Sources.instance.radios;
        final extra = Sources.instance.radiosExtra
            .where((r) => _q.isEmpty || r.name.contains(_q))
            .toList();
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                child: Row(children: [
                  const Text('البث المباشر', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 14),
                  const _LiveDot(),
                  const SizedBox(width: 6),
                  Text('محتاج نت', style: TextStyle(color: AppColors.muted, fontSize: 17)),
                ]),
              ),
            ),
            if (main.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    Sources.instance.refreshing ? 'بنجيب الإذاعات…' : 'الإذاعات هتظهر أول ما قايمة المصادر تتحدث (محتاج نت مرة واحدة).',
                    style: TextStyle(color: AppColors.muted, fontSize: 19),
                  ),
                ),
              ),
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 420,
                mainAxisExtent: 200,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _BigStation(st: main[i], index: i),
                childCount: main.length,
              ),
            ),
            if (Sources.instance.radiosExtra.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 26, 6, 12),
                  child: Row(children: [
                    Container(
                        width: 5,
                        height: 26,
                        decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 10),
                    const Text('إذاعات القرّاء', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 10),
                    Text('${Sources.instance.radiosExtra.length} إذاعة · قارئ واحد على مدار الساعة',
                        style: TextStyle(color: AppColors.muted, fontSize: 16)),
                    const Spacer(),
                    SizedBox(
                      width: 280,
                      child: TextField(
                        onChanged: (v) => setState(() => _q = v.trim()),
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          hintText: 'دوّر على قارئ…',
                          prefixIcon: Icon(Icons.search_rounded, color: AppColors.gold),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300,
                  mainAxisExtent: 84,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _SmallStation(st: extra[i]),
                  childCount: extra.length,
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }
}

bool _isPlaying(RadioStation st) => Player.instance.kind == PlayKind.radio && Player.instance.radioId == st.id;

Future<void> _tap(BuildContext context, RadioStation st) async {
  final p = Player.instance;
  if (_isPlaying(st)) {
    await p.toggle();
    return;
  }
  toast(context, 'بيتصل بـ ${st.name}…');
  final ok = await p.playRadio(st);
  if (!ok && context.mounted) toast(context, 'البث مش متاح دلوقتي — جرّب تاني أو اتأكد من النت');
}

class _BigStation extends StatelessWidget {
  final RadioStation st;
  final int index;
  const _BigStation({required this.st, required this.index});

  @override
  Widget build(BuildContext context) {
    final on = _isPlaying(st);
    final icons = {'egypt': Icons.radio_rounded, 'makkah': Icons.mosque_rounded, 'madinah': Icons.mosque_outlined};
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => _tap(context, st),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color.lerp(AppColors.bg1, [AppColors.gold, AppColors.emerald, AppColors.teal][index % 3], on ? 0.45 : 0.25)!,
                AppColors.bg0,
              ],
            ),
            border: Border.all(color: on ? AppColors.gold : Colors.white24, width: on ? 2.5 : 1),
            boxShadow: on ? [BoxShadow(color: AppColors.gold.withOpacity(0.3), blurRadius: 30)] : null,
          ),
          child: Row(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.25),
                  border: Border.all(color: AppColors.gold.withOpacity(0.6), width: 2),
                ),
                child: Icon(icons[st.id] ?? Icons.radio_rounded, color: AppColors.gold, size: 52),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const _LiveDot(),
                      const SizedBox(width: 6),
                      Text('مباشر', style: TextStyle(color: Colors.redAccent.shade100, fontSize: 15, fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 4),
                    Text(st.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.2)),
                    Text(st.desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, color: AppColors.muted)),
                  ],
                ),
              ),
              StreamBuilder<PlayerState>(
                stream: Player.instance.audio.playerStateStream,
                builder: (context, snap) {
                  final playing = on && (snap.data?.playing ?? false);
                  final loading = on &&
                      (snap.data?.processingState == ProcessingState.loading ||
                          snap.data?.processingState == ProcessingState.buffering);
                  return Stack(alignment: Alignment.center, children: [
                    GlassButton(
                      icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 76,
                      primary: true,
                      onTap: () => _tap(context, st),
                    ),
                    if (loading)
                      SizedBox(
                        width: 86,
                        height: 86,
                        child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.emerald),
                      ),
                  ]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallStation extends StatelessWidget {
  final RadioStation st;
  const _SmallStation({required this.st});

  @override
  Widget build(BuildContext context) {
    final on = _isPlaying(st);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _tap(context, st),
        child: Glass(
          blur: false,
          radius: 22,
          opacity: on ? 0.2 : 0.07,
          borderColor: on ? AppColors.gold : null,
          borderWidth: on ? 2 : 1.2,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Icon(on ? Icons.graphic_eq_rounded : Icons.radio_rounded, color: AppColors.gold, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(st.name.replaceAll('إذاعة', '').trim(),
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Pulsing red "live" dot.
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
        ),
      );
}
