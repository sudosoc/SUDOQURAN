import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'glass.dart';

class AboutTab extends StatelessWidget {
  const AboutTab({super.key});

  static const nameAr = 'سيف السيد علي';
  static const name = 'Seif Alsayed Ali';
  static const alias = 'SUDOSOC';
  static const email = 'ceo@sudosoc.com';
  static const portfolio = 'https://seif.sudosoc.com';
  static const github = 'https://github.com/sudosoc';
  static const repo = 'https://github.com/sudosoc/SUDOQURAN';

  static Future<void> open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && context.mounted) toast(context, 'مفيش تطبيق يفتح اللينك ده');
  }

  void _viewPhoto(BuildContext context) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => const _PhotoViewer(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        Glass(
          radius: 30,
          padding: const EdgeInsets.all(30),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _viewPhoto(context),
                child: Hero(
                  tag: 'dev-photo',
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: AppColors.gold, width: 4),
                      boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.35), blurRadius: 40)],
                      image: const DecorationImage(
                        image: AssetImage('assets/developer.jpg'),
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 34),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المطوّر · Developer', style: TextStyle(color: AppColors.gold, fontSize: 18, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    const Text(nameAr, style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text('$name · $alias',
                          style: TextStyle(fontSize: 22, color: AppColors.muted, letterSpacing: 1)),
                    ),
                    const SizedBox(height: 10),
                    Text('Cybersecurity · Network Security',
                        style: TextStyle(fontSize: 17, color: AppColors.emerald)),
                    const SizedBox(height: 6),
                    Text('اضغط على الصورة لتكبيرها', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _LinkCard(
                icon: Icons.alternate_email_rounded,
                ar: 'الإيميل',
                en: 'Email',
                onTap: () => open(context, Uri.parse('mailto:$email')),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _LinkCard(
                icon: Icons.language_rounded,
                ar: 'البورتفوليو',
                en: 'Portfolio',
                onTap: () => open(context, Uri.parse(portfolio)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _LinkCard(
                icon: Icons.code_rounded,
                ar: 'جيت هب',
                en: 'GitHub',
                onTap: () => open(context, Uri.parse(github)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Glass(
          radius: 26,
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset('assets/icon.png', width: 64, height: 64),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SUDOQURAN', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    Text('القرآن والرقية والأذكار — معمول مخصوص لشاشة العربية',
                        style: TextStyle(color: AppColors.muted, fontSize: 16)),
                  ],
                ),
              ),
              GlassButton(
                icon: Icons.open_in_new_rounded,
                label: 'الكود · Source',
                size: 56,
                onTap: () => open(context, Uri.parse(repo)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text('صدقة جارية — لا تنسونا من صالح دعائكم 🤍',
              style: TextStyle(color: AppColors.gold, fontSize: 18)),
        ),
      ],
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Center(
              child: Hero(
                tag: 'dev-photo',
                child: InteractiveViewer(
                  maxScale: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset('assets/developer_full.jpg', fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 24,
              left: 24,
              child: GlassButton(icon: Icons.close_rounded, size: 64, onTap: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label-only link card (Arabic + English, no raw address shown).
class _LinkCard extends StatelessWidget {
  final IconData icon;
  final String ar;
  final String en;
  final VoidCallback onTap;
  const _LinkCard({required this.icon, required this.ar, required this.en, required this.onTap});

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
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [AppColors.gold, AppColors.gold.withOpacity(0.6)]),
                ),
                child: Icon(icon, color: AppColors.bg0, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ar, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    Text(en, style: TextStyle(fontSize: 16, color: AppColors.muted, letterSpacing: 1)),
                  ],
                ),
              ),
              Icon(Icons.arrow_outward_rounded, color: AppColors.gold, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}
