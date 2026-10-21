import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('About Lovelle')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [LovelleColors.palePink, LovelleColors.cream],
                ),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.card_giftcard_rounded,
                    color: LovelleColors.rose,
                    size: 54,
                  ),
                  SizedBox(height: 16),
                  LovelleLogo(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Gifts are a way of saying, “I thought of you.”',
              style: TextStyle(
                color: LovelleColors.plum,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Lovelle is here to make thoughtful gifting feel simple and personal. Browse meaningful finds, add a note, and celebrate the little moments that bring people closer.',
              style: TextStyle(
                color: LovelleColors.mauve,
                fontSize: 15,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 22),
            const _ValueTile(
              icon: Icons.favorite_border_rounded,
              title: 'Thoughtful by design',
              text: 'Make every pick feel personal and full of care.',
            ),
            const SizedBox(height: 10),
            const _ValueTile(
              icon: Icons.spa_outlined,
              title: 'Made for meaningful moments',
              text: 'Celebrate the big milestones and everyday joys.',
            ),
          ],
        ),
      );
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: LovelleColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: LovelleColors.rose, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: LovelleColors.plum,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(text, style: const TextStyle(color: LovelleColors.mauve)),
                ],
              ),
            ),
          ],
        ),
      );
}
