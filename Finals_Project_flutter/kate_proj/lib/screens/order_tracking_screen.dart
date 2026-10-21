import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/order_status_summary.dart';

class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({super.key, required this.order});

  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final fulfillment =
        (order['fulfillment_method']?.toString() ?? 'delivery').toLowerCase();
    final isPickup = fulfillment == 'pickup';
    final status = (order['status']?.toString() ?? 'pending').toLowerCase();
    final orderNumber = order['order_number']?.toString() ?? 'Lovelle order';
    final milestones = isPickup
        ? const ['Ordered', 'Processing', 'Ready for pickup', 'Picked up']
        : const ['Ordered', 'Processing', 'Out for delivery', 'Delivered'];
    final activeIndex = switch (status) {
      'pending' => 0,
      'confirmed' || 'preparing' || 'processing' => 1,
      'shipped' when !isPickup => 2,
      'out_for_delivery' when !isPickup => 2,
      'ready_for_pickup' when isPickup => 2,
      'delivered' when !isPickup => 3,
      'picked_up' when isPickup => 3,
      _ => -1,
    };
    final createdAt = DateTime.tryParse(order['created_at']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(order['updated_at']?.toString() ?? '');

    return Scaffold(
      appBar: AppBar(title: const Text('Order tracking')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: LovelleColors.border),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR ORDER',
                  style: TextStyle(
                    color: LovelleColors.mauve,
                    letterSpacing: 1,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  orderNumber,
                  style: const TextStyle(
                    color: LovelleColors.plum,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isPickup ? 'Pickup order' : 'Delivery order',
                  style: const TextStyle(color: LovelleColors.mauve),
                ),
                const SizedBox(height: 8),
                Text(
                  peso.format(
                    double.tryParse(order['total_amount'].toString()) ?? 0,
                  ),
                  style: const TextStyle(
                    color: LovelleColors.roseDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          OrderStatusSummary(
            orderStatus: status,
            paymentStatus: order['payment_status']?.toString(),
            paymentMethod: order['payment_method']?.toString(),
          ),
          const SizedBox(height: 26),
          const Text(
            'Order progress',
            style: TextStyle(
              color: LovelleColors.plum,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          if (updatedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Last updated ${MaterialLocalizations.of(context).formatMediumDate(updatedAt)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(updatedAt))}',
                style: const TextStyle(
                  color: LovelleColors.mauve,
                  fontSize: 12,
                ),
              ),
            ),
          if (status == 'cancelled')
            const _CancelledState()
          else
            ...List.generate(milestones.length, (index) {
              final complete = activeIndex >= index;
              final timestamp = index == 0 ? createdAt : null;
              return _Milestone(
                title: milestones[index],
                complete: complete,
                isLast: index == milestones.length - 1,
                timestamp: timestamp,
              );
            }),
          const SizedBox(height: 16),
          const Text(
            'Progress reflects the latest order status available to Lovelle. Additional delivery updates are shown only when received.',
            style: TextStyle(
                color: LovelleColors.mauve, fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _Milestone extends StatelessWidget {
  const _Milestone({
    required this.title,
    required this.complete,
    required this.isLast,
    this.timestamp,
  });

  final String title;
  final bool complete;
  final bool isLast;
  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    final timestamp = this.timestamp;
    return SizedBox(
      height: 76,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: complete ? LovelleColors.rose : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          complete ? LovelleColors.rose : LovelleColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: complete
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: complete
                          ? LovelleColors.rose.withValues(alpha: .45)
                          : LovelleColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color:
                          complete ? LovelleColors.plum : LovelleColors.mauve,
                      fontWeight: complete ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (timestamp != null)
                    Text(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(timestamp),
                      style: const TextStyle(
                        color: LovelleColors.mauve,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelledState extends StatelessWidget {
  const _CancelledState();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: LovelleColors.palePink,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: LovelleColors.roseDark),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This order has been cancelled.',
                style: TextStyle(
                  color: LovelleColors.roseDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}
