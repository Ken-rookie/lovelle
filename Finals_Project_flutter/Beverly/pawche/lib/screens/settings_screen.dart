import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool push = true, orders = true, promos = false;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'These demo preferences reset when you close the app.',
            style: TextStyle(
              color: PawcheColors.muted,
              fontSize: 13,
            ),
          ),
        ),
        SwitchListTile(
            value: push,
            activeThumbColor: PawcheColors.pink,
            onChanged: (v) => setState(() => push = v),
            title: const Text('Push Notifications')),
        SwitchListTile(
            value: orders,
            activeThumbColor: PawcheColors.pink,
            onChanged: (v) => setState(() => orders = v),
            title: const Text('Order Updates')),
        SwitchListTile(
            value: promos,
            activeThumbColor: PawcheColors.pink,
            onChanged: (v) => setState(() => promos = v),
            title: const Text('Promotional Notifications')),
        const ListTile(title: Text('Language'), subtitle: Text('English')),
        const ListTile(title: Text('Currency'), subtitle: Text('PHP (₱)'))
      ]));
}
