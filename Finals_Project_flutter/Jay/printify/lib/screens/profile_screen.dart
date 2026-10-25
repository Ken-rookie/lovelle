import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.onSignIn,
    required this.onSignOut,
    required this.onNotifications,
  });
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final service = SupabaseService();
    final signedIn = service.authenticated;
    final user = service.currentUserEmail;
    final items = [
      (Icons.person_outline, 'Personal information', 'Name, email and phone'),
      (
        Icons.location_on_outlined,
        'Saved addresses',
        'Manage pickup or delivery',
      ),
      (Icons.payment_outlined, 'Payment methods', 'QRPh payment'),
      (Icons.notifications_none, 'Notifications', 'Order and payment updates'),
      (Icons.help_outline, 'Help & Support', 'FAQs and contact details'),
      (
        Icons.policy_outlined,
        'Terms & Privacy',
        'Policies and legal information',
      ),
      (Icons.settings_outlined, 'Settings', 'Language and appearance'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile & settings',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFFE5F1FF),
                    child: Icon(
                      Icons.person,
                      size: 34,
                      color: Color(0xFF0866F5),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          signedIn ? 'Printify customer' : 'Guest account',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          user ?? 'Sign in to sync your orders',
                          style: const TextStyle(color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Icon(item.$1, color: const Color(0xFF0866F5)),
                  title: Text(
                    item.$2,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(item.$3),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: item.$2 == 'Notifications'
                      ? onNotifications
                      : () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${item.$2} screen can be expanded here.',
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onSignIn,
              icon: const Icon(Icons.login),
              label: Text(signedIn ? 'Manage account' : 'Login / Sign up'),
            ),
          ),
          if (signedIn) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                try {
                  await service.signOut();
                  onSignOut();
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not log out: $error')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Log out', style: TextStyle(color: Colors.red)),
            ),
          ],
        ],
      ),
    );
  }
}
