import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'glass.dart';

class AboutTab extends StatelessWidget {
  const AboutTab({super.key});

  static const name = 'Seif Alsayed Ali';
  static const nameAr = 'سيف السيد علي';
  static const alias = 'SUDOSOC';
  static const email = 'sudosoc.seif@gmail.com';
  static const portfolio = 'https://seif.sudosoc.com';
  static const github = 'https://github.com/sudosoc';
  static const repo = 'https://github.com/sudosoc/SUDOQURAN';

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && context.mounted) toast(context, uri.toString());
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
              Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 4),
                  boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.35), blurRadius: 40)],
                  image: const DecorationImage(
                    image: AssetImage('assets/developer.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 34),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المطوّر', style: TextStyle(color: AppColors.gold, fontSize: 18, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    const Text(nameAr, style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text('$name · $alias',
                          style: TextStyle(fontSize: 22, color: AppColors.muted, letterSpacing: 1)),
                    ),
                    const SizedBox(height: 10),
                    Text('Cybersecurity · Network Security',
                        style: TextStyle(fontSize: 17, color: AppColors.emerald)),
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
                title: 'الإيميل',
                value: email,
                onTap: () => _open(context, Uri.parse('mailto:$email')),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _LinkCard(
                icon: Icons.language_rounded,
                title: 'البورتفوليو',
                value: 'seif.sudosoc.com',
                onTap: () => _open(context, Uri.parse(portfolio)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _LinkCard(
                icon: Icons.code_rounded,
                title: 'GitHub',
                value: 'github.com/sudosoc',
                onTap: () => _open(context, Uri.parse(github)),
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
              Image.asset('assets/icon.png', width: 64, height: 64),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SUDOQURAN', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    Text('تطبيق القرآن والرقية والأذكار للعربية — مفتوح المصدر',
                        style: TextStyle(color: AppColors.muted, fontSize: 16)),
                  ],
                ),
              ),
              GlassButton(
                icon: Icons.open_in_new_rounded,
                label: 'الكود',
                size: 56,
                onTap: () => _open(context, Uri.parse(repo)),
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

class _LinkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  const _LinkCard({required this.icon, required this.title, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Glass(
          blur: false,
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: AppColors.muted, fontSize: 15)),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
