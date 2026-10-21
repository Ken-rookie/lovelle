import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/common.dart';
import 'orders_screen.dart';
import 'addresses_screen.dart';
import 'reviews_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.onSignOut,
    required this.onWishlist,
  });

  final VoidCallback onSignOut;
  final VoidCallback onWishlist;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>?> _future;
  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getProfile();
  }

  Future<void> _edit() async {
    Map<String, dynamic>? current;
    try {
      current = await _future;
    } catch (error) {
      if (mounted) showOperationError(context, error);
      return;
    }
    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(
      text: current?['full_name']?.toString() ?? '',
    );
    final phone = TextEditingController(
      text: current?['phone']?.toString() ?? '',
    );
    final addressLine = TextEditingController(
      text: current?['address_line']?.toString() ?? '',
    );
    final city = TextEditingController(
      text: current?['city']?.toString() ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit profile'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your name'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                ),
                const SizedBox(height: 18),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Default delivery address',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: addressLine,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Street / barangay',
                  ),
                  validator: (value) {
                    if (city.text.trim().isNotEmpty &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Enter your street or barangay';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: city,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'City'),
                  validator: (value) {
                    if (addressLine.text.trim().isNotEmpty &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Enter your city';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                const Text(
                  'Leave both address fields blank if you do not want to save a delivery address.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save changes'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await SupabaseService.updateProfile(
          name: name.text,
          phone: phone.text,
          addressLine: addressLine.text,
          city: city.text,
        );
        if (mounted) {
          setState(() {
            _future = SupabaseService.getProfile();
          });
          showMessage(context, 'Profile updated');
        }
      } catch (error) {
        if (mounted) showOperationError(context, error);
      }
    }
    name.dispose();
    phone.dispose();
    addressLine.dispose();
    city.dispose();
  }

  Future<void> _logout() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        icon: const Icon(Icons.logout_rounded, color: giftlyPink, size: 34),
        title: const Text('Log out?'),
        content:
            const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await SupabaseService.signOut();
      if (mounted) widget.onSignOut();
    } catch (error) {
      if (mounted) showOperationError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My profile')),
        body: FutureBuilder<Map<String, dynamic>?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingState(label: 'Opening your profile…');
            }
            if (snapshot.hasError) {
              return LoadErrorState(
                error: snapshot.error!,
                onRetry: () => setState(
                  () => _future = SupabaseService.getProfile(),
                ),
              );
            }
            final profile = snapshot.data ?? {};
            final name = profile['full_name']?.toString().trim();
            final displayName =
                name == null || name.isEmpty ? 'Lovelle customer' : name;
            final email = profile['email']?.toString() ??
                SupabaseService.client.auth.currentUser?.email ??
                '';

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF2DCE4)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 31,
                        backgroundColor: Color(0xFFFFE5EB),
                        child: Icon(
                          Icons.person_rounded,
                          color: giftlyPink,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: giftlyInk,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit profile',
                        onPressed: _edit,
                        icon:
                            const Icon(Icons.edit_outlined, color: giftlyPink),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Padding(
                  padding: EdgeInsets.only(left: 5, bottom: 8),
                  child: Text(
                    'YOUR LOVELLE',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                      color: Colors.black45,
                    ),
                  ),
                ),
                _item(
                  Icons.person_outline,
                  'Edit profile',
                  'Update your personal information',
                  _edit,
                ),
                _item(
                  Icons.receipt_long_outlined,
                  'My orders',
                  'Follow the journey of your gifts',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OrdersScreen()),
                  ),
                ),
                _item(
                  Icons.favorite_border_rounded,
                  'Wishlist',
                  'Your saved gift ideas',
                  widget.onWishlist,
                ),
                _item(
                  Icons.location_on_outlined,
                  'Saved addresses',
                  'Manage delivery addresses',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddressesScreen()),
                  ),
                ),
                _item(
                  Icons.star_border_rounded,
                  'Reviews',
                  'Your product feedback',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReviewsScreen()),
                  ),
                ),
                _item(
                  Icons.settings_outlined,
                  'Settings',
                  'Preferences and app information',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
                _item(
                  Icons.spa_outlined,
                  'About Lovelle',
                  'Our little story',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Log out'),
                ),
              ],
            );
          },
        ),
      );

  Widget _item(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) =>
      Card(
        child: ListTile(
          leading: Icon(icon, color: giftlyPink),
          title: Text(
            title,
            style: const TextStyle(
              color: giftlyInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}
