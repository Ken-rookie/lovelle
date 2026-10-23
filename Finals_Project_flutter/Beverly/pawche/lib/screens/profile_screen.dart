import 'package:flutter/material.dart';

import '../config/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'addresses_screen.dart';
import 'login_screen.dart';
import 'my_pets_screen.dart';
import 'notifications_screen.dart';
import 'order_history_screen.dart';
import 'settings_screen.dart';
import 'wishlist_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: PawcheColors.blush,
              elevation: 0,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                leading: const PetAvatar(type: 'Dog', size: 54),
                title: const Text(
                  'Juan Dela Cruz',
                  style: TextStyle(
                    color: PawcheColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: const Text('juan@email.com · Demo profile'),
                trailing: IconButton(
                  tooltip: 'Edit personal information',
                  onPressed: () => showMessage(
                    context,
                    'Connect this form to profiles table',
                  ),
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: PawcheColors.darkPink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _item(
              context,
              Icons.person_outline,
              'Personal Information',
              () => showMessage(
                context,
                'Connect this form to profiles table',
              ),
            ),
            _item(
              context,
              Icons.location_on_outlined,
              'Delivery Addresses',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddressesScreen(),
                ),
              ),
            ),
            _item(
              context,
              Icons.pets_outlined,
              'My Pets',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyPetsScreen(),
                ),
              ),
            ),
            _item(
              context,
              Icons.favorite_border,
              'Wishlist',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WishlistScreen(),
                ),
              ),
            ),
            _item(
              context,
              Icons.receipt_long_outlined,
              'Order History',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OrderHistoryScreen(),
                ),
              ),
            ),
            _item(
              context,
              Icons.notifications_none,
              'Notifications',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                ),
              ),
            ),
            _item(
              context,
              Icons.settings_outlined,
              'Settings',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                await SupabaseService.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                    (_) => false,
                  );
                }
              },
              icon: const Icon(
                Icons.logout,
                color: PawcheColors.pink,
              ),
              label: const Text(
                'Log Out',
                style: TextStyle(color: PawcheColors.pink),
              ),
            ),
          ],
        ),
      );

  Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) =>
      Card(
        color: Colors.white,
        child: ListTile(
          leading: Icon(icon, color: PawcheColors.muted),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
