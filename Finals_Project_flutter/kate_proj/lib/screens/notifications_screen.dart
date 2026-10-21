import 'package:flutter/material.dart';
import '../screens/order_tracking_screen.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _orders;

  @override
  void initState() {
    super.initState();
    _orders = SupabaseService.getOrders();
  }

  Future<void> _refresh() async {
    setState(() => _orders = SupabaseService.getOrders());
    await _orders;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Order updates')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _orders,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingState(label: 'Checking your order updates…');
            }
            if (snapshot.hasError) {
              return LoadErrorState(
                error: snapshot.error!,
                onRetry: () => setState(
                  () => _orders = SupabaseService.getOrders(),
                ),
              );
            }
            final orders = snapshot.data ?? [];
            if (orders.isEmpty) {
              return const EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'Nothing new just yet',
                subtitle: 'Updates about your orders will appear here.',
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final orderNo =
                      order['order_number']?.toString() ?? 'your gift order';
                  final status = (order['status']?.toString() ?? 'pending')
                      .replaceAll('_', ' ');
                  final date =
                      DateTime.tryParse(order['created_at']?.toString() ?? '');
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: LovelleColors.border),
                      ),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: LovelleColors.palePink,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_shipping_outlined,
                          color: LovelleColors.roseDark,
                        ),
                      ),
                      title: Text(
                        'Order $orderNo',
                        style: const TextStyle(
                          color: LovelleColors.plum,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Current status: $status'
                          '${date == null ? '' : '\nPlaced ${MaterialLocalizations.of(context).formatMediumDate(date)}'}',
                          style: const TextStyle(
                            color: LovelleColors.mauve,
                            height: 1.4,
                          ),
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: LovelleColors.mauve,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => OrderTrackingScreen(order: order),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
}
