import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Delivery Addresses')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Sample delivery address · address changes are not saved yet.',
              style: TextStyle(color: PawcheColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Card(
              color: Colors.white,
              child: ListTile(
                leading: Icon(Icons.location_on, color: PawcheColors.pink),
                title: Text('Home'),
                subtitle: Text(
                  'San Vicente Subdivision, Cebu City, Cebu 6300',
                ),
                trailing: Text('Default'),
              ),
            ),
            PinkButton(
              label: 'Add New Address',
              onPressed: () => showMessage(
                context,
                'Address saving is not connected in this demo.',
              ),
            ),
          ],
        ),
      );
}
