import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/order_status_summary.dart';
import 'order_tracking_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getOrders();
  }

  Future<void> _refresh() async {
    setState(() => _future = SupabaseService.getOrders());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    const statuses = [
      'all',
      'pending',
      'confirmed',
      'preparing',
      'processing',
      'out_for_delivery',
      'ready_for_pickup',
      'shipped',
      'delivered',
      'picked_up',
      'cancelled',
    ];
    return Scaffold(
      appBar: AppBar(
          title: const Text('My Orders',
              style: TextStyle(fontWeight: FontWeight.w800))),
      body: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
              children: statuses
                  .map((status) => Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ChoiceChip(
                          label: Text(status == 'all'
                              ? 'All'
                              : orderStatusLabel(status)),
                          selected: _filter == status,
                          onSelected: (_) => setState(() => _filter = status),
                        ),
                      ))
                  .toList()),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const AppLoadingState(label: 'Finding your orders…');
              }
              if (snap.hasError) {
                return LoadErrorState(
                  error: snap.error!,
                  onRetry: () =>
                      setState(() => _future = SupabaseService.getOrders()),
                );
              }
              final all = snap.data ?? [];
              final rows = _filter == 'all'
                  ? all
                  : all.where((r) => r['status'] == _filter).toList();
              if (rows.isEmpty) {
                return const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No orders yet',
                    subtitle: 'Your gift orders will appear here.');
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final order = rows[i];
                    final items = (order['order_items'] as List? ?? []);
                    final roseChoices = items
                        .whereType<Map>()
                        .where((item) => item['rose_type'] != null)
                        .map((item) => item['rose_type'] == 'fresh'
                            ? 'Fresh'
                            : 'Artificial')
                        .toSet()
                        .join(', ');
                    final total =
                        double.tryParse(order['total_amount'].toString()) ?? 0;
                    final rawStatus = order['status']?.toString() ?? 'pending';
                    final createdAt = DateTime.tryParse(
                        order['created_at']?.toString() ?? '');
                    final isComplete = const {
                      'delivered',
                      'picked_up',
                    }.contains(rawStatus);
                    final isCancelled = rawStatus == 'cancelled';
                    return Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(color: const Color(0xFFF4E2E9))),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                      child: Text(
                                          order['order_number']?.toString() ??
                                              'Lovelle order',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800))),
                                  Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                          color: isComplete
                                              ? const Color(0xFFE6F2E9)
                                              : isCancelled
                                                  ? LovelleColors.palePink
                                                  : const Color(0xFFFFEAF1),
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Text(orderStatusLabel(rawStatus),
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isComplete
                                                  ? LovelleColors.sage
                                                  : LovelleColors.roseDark))),
                                ]),
                            const SizedBox(height: 8),
                            Text(
                                '${items.length} ${items.length == 1 ? 'item' : 'items'} · ${order['fulfillment_method'] == 'pickup' ? 'Pickup' : 'Delivery'}',
                                style: const TextStyle(color: Colors.black54)),
                            if (roseChoices.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Rose style: $roseChoices',
                                style: const TextStyle(
                                  color: LovelleColors.mauve,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (createdAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Placed ${MaterialLocalizations.of(context).formatMediumDate(createdAt)}',
                                style: const TextStyle(
                                    color: LovelleColors.mauve, fontSize: 12),
                              ),
                            ],
                            const SizedBox(height: 12),
                            OrderStatusSummary(
                              orderStatus: rawStatus,
                              paymentStatus:
                                  order['payment_status']?.toString(),
                              paymentMethod:
                                  order['payment_method']?.toString(),
                            ),
                            const SizedBox(height: 12),
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(peso.format(total),
                                      style: const TextStyle(
                                          fontSize: 17,
                                          color: giftlyPink,
                                          fontWeight: FontWeight.w800)),
                                ]),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        OrderTrackingScreen(order: order),
                                  ),
                                ),
                                icon:
                                    const Icon(Icons.route_outlined, size: 17),
                                label: const Text('Track order'),
                              ),
                            ),
                            if (order['status'] == 'pending' &&
                                order['payment_method'] == 'cash_on_delivery' &&
                                order['payment_status']
                                        ?.toString()
                                        .toLowerCase() !=
                                    'paid')
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () async {
                                    final yes = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Cancel order?'),
                                        content: const Text(
                                            'Only pending cash-on-delivery orders can be cancelled.'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Keep order')),
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child:
                                                  const Text('Cancel order')),
                                        ],
                                      ),
                                    );
                                    if (yes == true) {
                                      try {
                                        await SupabaseService
                                            .cancelOwnPendingOrder(
                                                order['id'].toString());
                                        if (!mounted) return;
                                        setState(() => _future =
                                            SupabaseService.getOrders());
                                      } catch (e) {
                                        if (!mounted) return;
                                        if (context.mounted) {
                                          showOperationError(context, e);
                                        }
                                      }
                                    }
                                  },
                                  child: const Text('Cancel order'),
                                ),
                              ),
                          ]),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
