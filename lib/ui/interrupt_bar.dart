import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/player.dart';
import 'glass.dart';

/// Big floating "stop" pill shown whenever the adhan or du'a al-rukub is playing
/// inside the app — one tap silences it (e.g. when a phone call comes in).
class InterruptBar extends StatelessWidget {
  const InterruptBar({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Player.instance;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final on = p.kind == PlayKind.special;
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          left: 0,
          right: 0,
          bottom: on ? 28 : -140,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(50),
                onTap: on ? p.stopInterrupt : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    gradient: LinearGradient(colors: [AppColors.gold, Color.lerp(AppColors.gold, Colors.black, 0.3)!]),
                    boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.45), blurRadius: 30)],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.stop_circle_rounded, color: AppColors.bg0, size: 44),
                    const SizedBox(width: 14),
                    Text('إيقاف ${p.title}',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.bg0)),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Lets the user grant "display over other apps" so the floating stop button
/// appears on top of navigation/other apps while the adhan or du'a plays.
class StopBubbleCard extends StatefulWidget {
  const StopBubbleCard({super.key});

  @override
  State<StopBubbleCard> createState() => _StopBubbleCardState();
}

class _StopBubbleCardState extends State<StopBubbleCard> with WidgetsBindingObserver {
  static const _ch = MethodChannel('sudoquran/overlay');
  bool? _ok;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    try {
      final v = await _ch.invokeMethod<bool>('canDraw');
      if (mounted) setState(() => _ok = v ?? false);
    } catch (_) {
      if (mounted) setState(() => _ok = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ok = _ok ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Glass(
        borderColor: ok ? null : AppColors.gold,
        child: Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.stop_circle_outlined, color: AppColors.gold, size: 44),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('زرار الإيقاف العائم', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                ok
                    ? 'شغّال ✓ — وقت الأذان أو الدعاء هيظهر زرار "إيقاف" فوق أي تطبيق، ولو جالك تليفون بيسكت لوحده'
                    : 'اسمح للتطبيق يظهر فوق التطبيقات التانية عشان زرار "إيقاف" يطلعلك فوق الخريطة وقت الأذان أو الدعاء',
                style: TextStyle(fontSize: 16, color: AppColors.muted),
              ),
            ]),
          ),
          if (!ok) ...[
            const SizedBox(width: 12),
            GlassButton(
              icon: Icons.open_in_new_rounded,
              label: 'اسمح',
              size: 50,
              primary: true,
              onTap: () async {
                try {
                  await _ch.invokeMethod('request');
                } catch (_) {}
              },
            ),
          ],
        ]),
      ),
    );
  }
}
