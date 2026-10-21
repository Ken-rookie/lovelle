import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'about_screen.dart';
import 'notifications_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'YOUR EXPERIENCE',
              style: TextStyle(
                color: LovelleColors.mauve,
                letterSpacing: 1,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _SettingsRow(
              icon: Icons.notifications_none_rounded,
              title: 'Order updates',
              subtitle: 'See the latest status from your orders',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'ABOUT',
              style: TextStyle(
                color: LovelleColors.mauve,
                letterSpacing: 1,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _SettingsRow(
              icon: Icons.spa_outlined,
              title: 'About Lovelle',
              subtitle: "More than gifts, it's a feeling.",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Notifications shown in Lovelle are based on your saved order information.',
              style: TextStyle(
                color: LovelleColors.mauve,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon, color: LovelleColors.rose),
          title: Text(
            title,
            style: const TextStyle(
              color: LovelleColors.plum,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}
