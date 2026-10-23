import 'package:flutter/material.dart';

import '../data/checkout_repository.dart';
import '../models/checkout.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/order_product_thumbnail.dart';
import 'order_tracking_screen.dart';
import 'shop_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  late Future<List<OrderHistoryEntry>> _orders;

  @override
  void initState() {
    super.initState();
    _orders = CheckoutRepository.loadOrderHistory();
  }

  void _reload() {
    setState(() => _orders = CheckoutRepository.loadOrderHistory());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('My orders'),
          actions: [
            IconButton(
              tooltip: 'Refresh orders',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: FutureBuilder<List<OrderHistoryEntry>>(
          future: _orders,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: PawcheColors.pink),
                    SizedBox(height: 14),
                    Text(
                      'Loading your orders…',
                      style: TextStyle(color: PawcheColors.muted),
                    ),
                  ],
                ),
              );
            }
            if (snapshot.hasError) {
              return _OrderHistoryError(
                message: _errorMessage(snapshot.error!),
                onRetry: _reload,
              );
            }
            final orders = snapshot.data ?? const <OrderHistoryEntry>[];
            if (orders.isEmpty) return const _EmptyOrderHistory();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _HistoryHeader(orderCount: orders.length),
                const SizedBox(height: 14),
                for (final entry in orders) ...[
                  OrderHistoryCard(
                    entry: entry,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderTrackingScreen(order: entry.order),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      );

  String _errorMessage(Object error) {
    final message =
        error.toString().replaceFirst(RegExp(r'^(Exception|StateError): '), '');
    if (message.contains('not configured')) {
      return 'Order history needs a configured Supabase connection. Please try again later.';
    }
    if (message.contains('Sign in')) return message;
    return 'We couldn’t load your orders. Check your connection and try again.';
  }
}

class _HistoryHeader extends StatelessWidget {
  final int orderCount;

  const _HistoryHeader({required this.orderCount});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF1F5), Color(0xFFFFFAFC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: PawcheColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: PawcheColors.darkPink,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your order details, all in one place',
                    style: TextStyle(
                      color: PawcheColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Payment, delivery and item details · $orderCount ${orderCount == 1 ? 'order' : 'orders'}',
                    style: const TextStyle(
                      color: PawcheColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class OrderHistoryCard extends StatelessWidget {
  final OrderHistoryEntry entry;
  final VoidCallback onTap;

  const OrderHistoryCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final order = entry.order;
    final firstItem = entry.items.isEmpty ? null : entry.items.first;
    final itemCount =
        entry.items.fold<int>(0, (total, item) => total + item.quantity);
    final address = _deliveryAddress(entry.shippingAddress);
    final displayedItemCount =
        entry.items.length > 2 ? 2 : entry.items.length;
    final totalLabel = switch (order.paymentStatus) {
      'paid' => 'Total paid',
      'unpaid' => 'Cash due on delivery',
      'expired' => 'Order total',
      _ => 'Total to pay',
    };

    return Card(
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: PawcheColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OrderProductThumbnail(item: firstItem, size: 70),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ORDER REFERENCE',
                          style: TextStyle(
                            color: PawcheColors.muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .7,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          order.referenceNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PawcheColors.navy,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_dateLabel(entry.createdAt)} at ${_timeLabel(entry.createdAt)}',
                          style: const TextStyle(
                            color: PawcheColors.muted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$itemCount ${itemCount == 1 ? 'item' : 'items'} · ${_paymentMethod(order.paymentMethod)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PawcheColors.navy,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const Divider(height: 1, color: PawcheColors.border),
              const SizedBox(height: 13),
              const _CardSectionTitle(
                icon: Icons.track_changes_rounded,
                title: 'Order and payment status',
              ),
              const SizedBox(height: 10),
              _OrderStatusDetails(order: order),
              const SizedBox(height: 15),
              const Divider(height: 1, color: PawcheColors.border),
              const SizedBox(height: 13),
              const _CardSectionTitle(
                icon: Icons.shopping_bag_outlined,
                title: 'Items ordered',
              ),
              const SizedBox(height: 8),
              if (entry.items.isEmpty)
                const Text(
                  'Item details are unavailable for this order.',
                  style: TextStyle(color: PawcheColors.muted, fontSize: 12),
                )
              else ...[
                for (final item in entry.items.take(displayedItemCount))
                  _HistoryItemRow(item: item),
                if (entry.items.length > displayedItemCount)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      '+ ${entry.items.length - displayedItemCount} more ${entry.items.length - displayedItemCount == 1 ? 'product' : 'products'} — open order for the full list',
                      style: const TextStyle(
                        color: PawcheColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 14),
              const Divider(height: 1, color: PawcheColors.border),
              const SizedBox(height: 13),
              const _CardSectionTitle(
                icon: Icons.local_shipping_outlined,
                title: 'Delivery address',
              ),
              const SizedBox(height: 7),
              Text(
                address,
                style: const TextStyle(
                  color: PawcheColors.navy,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _PriceRow('Items subtotal', entry.subtotal),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Delivery fee',
                            style: TextStyle(
                              color: PawcheColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          entry.deliveryFee == 0
                              ? 'FREE'
                              : formatPeso(entry.deliveryFee),
                          style: TextStyle(
                            color: entry.deliveryFee == 0
                                ? PawcheColors.green
                                : PawcheColors.navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 9),
                      child: Divider(height: 1),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            totalLabel,
                            style: const TextStyle(
                              color: PawcheColors.navy,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          formatPeso(order.totalAmount),
                          style: const TextStyle(
                            color: PawcheColors.darkPink,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: PawcheColors.muted,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tap to see full order details and refresh its status.',
                      style: TextStyle(
                        color: PawcheColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Text(
                    'View details',
                    style: TextStyle(
                      color: PawcheColors.darkPink,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: PawcheColors.darkPink,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dateLabel(DateTime date) {
    final local = date.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  String _timeLabel(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _paymentMethod(String method) =>
      method == 'qrph' ? 'PayMongo QRPH' : 'Cash on Delivery';

  String _deliveryAddress(Map<String, dynamic> address) {
    final name = address['full_name'] as String?;
    final line1 = address['address_line1'] as String?;
    final line2 = address['address_line2'] as String?;
    final barangay = address['barangay'] as String?;
    final municipality =
        address['municipality'] as String? ?? address['city'] as String?;
    final province = address['province'] as String?;
    final postalCode = address['postal_code'] as String?;
    final phone = address['phone'] as String?;
    final note = address['delivery_note'] as String?;
    final locality = [barangay, municipality, province]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(', ');
    final addressLine = [line1, line2, locality, postalCode]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(', ');
    final details = [
      if (name != null && name.trim().isNotEmpty) name,
      if (addressLine.isNotEmpty) addressLine,
      if (phone != null && phone.trim().isNotEmpty) phone,
      if (note != null && note.trim().isNotEmpty) 'Delivery note: $note',
    ];
    return details.isEmpty ? 'Delivery address unavailable' : details.join('\n');
  }
}

class _CardSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _CardSectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: PawcheColors.darkPink),
          const SizedBox(width: 7),
          Text(
            title,
            style: const TextStyle(
              color: PawcheColors.navy,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
}

class _OrderStatusDetails extends StatelessWidget {
  final CheckoutOrder order;

  const _OrderStatusDetails({required this.order});

  @override
  Widget build(BuildContext context) {
    final (orderTitle, orderDescription, orderColor, orderBackground) =
        switch (order.status) {
      'awaiting_payment' => (
          'Awaiting payment',
          'Complete QRPH payment to confirm this order.',
          PawcheColors.darkPink,
          PawcheColors.blush,
        ),
      'confirmed' => (
          'Order confirmed',
          'Your order is saved. Check back here for updates.',
          PawcheColors.green,
          const Color(0xFFEFF9F4),
        ),
      'cancelled' => (
          'Order cancelled',
          'This order is no longer active.',
          PawcheColors.muted,
          const Color(0xFFF2F3F5),
        ),
      _ => (
          _humanize(order.status),
          'See order details for the latest information.',
          PawcheColors.muted,
          const Color(0xFFF2F3F5),
        ),
    };
    final (paymentTitle, paymentDescription, paymentColor) =
        switch (order.paymentStatus) {
      'paid' => (
          'Paid',
          'Payment received through PayMongo QRPH.',
          PawcheColors.green,
        ),
      'unpaid' => (
          'Due on delivery',
          'Pay ${formatPeso(order.totalAmount)} in cash to the courier.',
          PawcheColors.darkPink,
        ),
      'expired' => (
          'Payment expired',
          'QRPH payment was not completed before the code expired.',
          PawcheColors.darkPink,
        ),
      _ => (
          'Awaiting QRPH payment',
          'Payment is not confirmed yet. Open the order to check again.',
          PawcheColors.darkPink,
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusDetail(
          label: 'Order status',
          value: orderTitle,
          description: orderDescription,
          color: orderColor,
          background: orderBackground,
        ),
        const SizedBox(height: 9),
        _StatusDetail(
          label: 'Payment status',
          value: paymentTitle,
          description: paymentDescription,
          color: paymentColor,
          background: Colors.white,
        ),
      ],
    );
  }
}

class _StatusDetail extends StatelessWidget {
  final String label;
  final String value;
  final String description;
  final Color color;
  final Color background;

  const _StatusDetail({
    required this.label,
    required this.value,
    required this.description,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PawcheColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: PawcheColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                color: PawcheColors.navy,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
}

class _HistoryItemRow extends StatelessWidget {
  final OrderHistoryItem item;

  const _HistoryItemRow({required this.item});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PawcheColors.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.quantity} × ${formatPeso(item.unitPrice)} each',
                    style: const TextStyle(
                      color: PawcheColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatPeso(item.quantity * item.unitPrice),
              style: const TextStyle(
                color: PawcheColors.navy,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class _PriceRow extends StatelessWidget {
  final String label;
  final int amount;

  const _PriceRow(this.label, this.amount);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: PawcheColors.muted,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            formatPeso(amount),
            style: const TextStyle(
              color: PawcheColors.navy,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

String _humanize(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

class _OrderHistoryError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _OrderHistoryError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 42,
                color: PawcheColors.darkPink,
              ),
              const SizedBox(height: 12),
              const Text(
                'Orders are temporarily unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: PawcheColors.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: PawcheColors.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
}

class _EmptyOrderHistory extends StatelessWidget {
  const _EmptyOrderHistory();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: const BoxDecoration(
                  color: PawcheColors.blush,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 36,
                  color: PawcheColors.darkPink,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No orders yet',
                style: TextStyle(
                  color: PawcheColors.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Your purchases will appear here, ready to track whenever you need them.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PawcheColors.muted, height: 1.45),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShopScreen()),
                ),
                child: const Text('Explore the shop'),
              ),
            ],
          ),
        ),
      );
}
