import 'package:flutter/material.dart';
import '../widgets/section_title.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onUpload,
    required this.onOrders,
    required this.onNotifications,
  });
  final VoidCallback onUpload;
  final VoidCallback onOrders;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final services = [
      ('Documents', Icons.description_outlined, const Color(0xFF16B86A)),
      ('Photos', Icons.image_outlined, const Color(0xFFC43FE8)),
      ('ID & Passports', Icons.badge_outlined, const Color(0xFF0866F5)),
      ('Tarpaulin', Icons.crop_landscape, const Color(0xFFFF6262)),
      ('Stickers', Icons.sell_outlined, const Color(0xFFFFA21A)),
      ('Others', Icons.add_circle_outline, const Color(0xFF8A55E8)),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            const Icon(Icons.print_rounded, color: Color(0xFF0866F5), size: 30),
            const SizedBox(width: 8),
            const Text(
              'Printify',
              style: TextStyle(
                fontSize: 22,
                color: Color(0xFF0866F5),
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Notifications',
              onPressed: onNotifications,
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Hello, there! 👋',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          'What would you like to print today?',
          style: TextStyle(color: Colors.blueGrey),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                icon: Icons.upload_file_rounded,
                label: 'Upload Files',
                color: const Color(0xFF0866F5),
                onTap: onUpload,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAction(
                icon: Icons.dashboard_customize_outlined,
                label: 'Choose Template',
                color: const Color(0xFF14B86B),
                onTap: onUpload,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAction(
                icon: Icons.receipt_long_outlined,
                label: 'My Orders',
                color: const Color(0xFFFF9B21),
                onTap: onOrders,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF0B3B85), Color(0xFF0874F9)],
            ),
          ),
          child: const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quality Prints, Fast Turnaround!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Choose your files and customize every print detail.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.local_print_shop_outlined,
                color: Colors.white,
                size: 42,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Popular services'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: services.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.05,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, i) {
            final item = services[i];
            return InkWell(
              onTap: onUpload,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE1EBF8)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.$2, color: item.$3, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      item.$1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      height: 100,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE1EBF8)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}
