import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            PawchePageTitle(
              'Recent Updates',
              subtitle: 'Sample notifications · live alerts are not connected.',
            ),
            Card(
              color: Colors.white,
              child: ListTile(
                leading: Icon(
                  Icons.local_shipping_outlined,
                  color: PawcheColors.pink,
                ),
                title: Text('Your order is processing'),
                subtitle: Text('We are preparing your Pawché order.'),
              ),
            ),
            Card(
              color: Colors.white,
              child: ListTile(
                leading: Icon(
                  Icons.notifications_outlined,
                  color: PawcheColors.pink,
                ),
                title: Text('Welcome to Pawché!'),
                subtitle: Text('Thank you for caring for your furry loves.'),
              ),
            ),
          ],
        ),
      );
}
