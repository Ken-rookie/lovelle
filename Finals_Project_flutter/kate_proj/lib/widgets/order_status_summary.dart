import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

String orderStatusLabel(String? status) {
  switch (status?.toLowerCase()) {
    case 'pending':
      return 'Pending';
    case 'confirmed':
      return 'Confirmed';
    case 'preparing':
      return 'Being prepared';
    case 'processing':
      return 'Processing';
    case 'out_for_delivery':
      return 'Out for delivery';
    case 'shipped':
      return 'Shipped';
    case 'ready_for_pickup':
      return 'Ready for pickup';
    case 'delivered':
      return 'Delivered';
    case 'picked_up':
      return 'Picked up';
    case 'cancelled':
    case 'canceled':
      return 'Cancelled';
    default:
      return _titleCase(status);
  }
}

String orderStatusDescription(String? status) {
  switch (status?.toLowerCase()) {
    case 'pending':
      return 'Your order has been received and is awaiting confirmation.';
    case 'confirmed':
      return 'Your order is confirmed and will be prepared soon.';
    case 'preparing':
    case 'processing':
      return 'Your gift is being prepared.';
    case 'out_for_delivery':
    case 'shipped':
      return 'Your order is on its way to the delivery address.';
    case 'ready_for_pickup':
      return 'Your order is ready for pickup.';
    case 'delivered':
      return 'Your order has been delivered.';
    case 'picked_up':
      return 'Your order has been picked up.';
    case 'cancelled':
    case 'canceled':
      return 'This order has been cancelled.';
    default:
      return 'Check back for the latest order update.';
  }
}

String paymentStatusLabel(String? status) {
  switch (status?.toLowerCase()) {
    case 'paid':
      return 'Paid';
    case 'pending':
      return 'Pending';
    case 'failed':
      return 'Failed';
    case 'refunded':
      return 'Refunded';
    default:
      return _titleCase(status);
  }
}

String paymentStatusDescription(String? status, String? method) {
  switch (status?.toLowerCase()) {
    case 'paid':
      return 'Payment received and confirmed.';
    case 'pending':
      if (method?.toLowerCase() == 'cash_on_delivery') {
        return 'Payment is due when your order arrives or is picked up.';
      }
      return 'Payment has not been confirmed yet.';
    case 'failed':
      return 'Payment was not completed. Contact support for help.';
    case 'refunded':
      return 'Your payment has been refunded.';
    default:
      return 'Check back for the latest payment update.';
  }
}

String paymentMethodLabel(String? method) {
  switch (method?.toLowerCase()) {
    case 'cash_on_delivery':
      return 'Cash on delivery';
    case 'paymongo':
      return 'PayMongo QRPH';
    case 'gcash':
      return 'GCash';
    case 'maya':
      return 'Maya';
    case 'card':
      return 'Card';
    default:
      return _titleCase(method);
  }
}

String _titleCase(String? value) {
  final words = (value ?? '').trim().replaceAll('_', ' ').split(' ');
  final title = words
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
  return title.isEmpty ? 'Unavailable' : title;
}

class OrderStatusSummary extends StatelessWidget {
  const OrderStatusSummary({
    super.key,
    required this.orderStatus,
    required this.paymentStatus,
    required this.paymentMethod,
  });

  final String? orderStatus;
  final String? paymentStatus;
  final String? paymentMethod;

  @override
  Widget build(BuildContext context) {
    final isCancelled =
        const {'cancelled', 'canceled'}.contains(orderStatus?.toLowerCase());
    final isComplete =
        const {'delivered', 'picked_up'}.contains(orderStatus?.toLowerCase());
    final isPaid = paymentStatus?.toLowerCase() == 'paid';
    final isRefunded = paymentStatus?.toLowerCase() == 'refunded';
    final method = paymentMethod;
    final methodDescription = method == null || method.isEmpty
        ? ''
        : ' · ${paymentMethodLabel(method)}';

    return Column(
      children: [
        _StatusDetail(
          label: 'ORDER STATUS',
          value: orderStatusLabel(orderStatus),
          description: orderStatusDescription(orderStatus),
          icon: isCancelled
              ? Icons.cancel_outlined
              : isComplete
                  ? Icons.check_circle_outline_rounded
                  : Icons.local_shipping_outlined,
          color: isCancelled
              ? LovelleColors.roseDark
              : isComplete
                  ? LovelleColors.sage
                  : LovelleColors.roseDark,
        ),
        const SizedBox(height: 8),
        _StatusDetail(
          label: 'PAYMENT',
          value: paymentStatusLabel(paymentStatus),
          description:
              '${paymentStatusDescription(paymentStatus, paymentMethod)}$methodDescription',
          icon: isPaid
              ? Icons.verified_outlined
              : isRefunded
                  ? Icons.currency_exchange_rounded
                  : Icons.payments_outlined,
          color: isPaid
              ? LovelleColors.sage
              : isRefunded
                  ? LovelleColors.mauve
                  : LovelleColors.roseDark,
        ),
      ],
    );
  }
}

class _StatusDetail extends StatelessWidget {
  const _StatusDetail({
    required this.label,
    required this.value,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String description;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .15)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: LovelleColors.mauve,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: LovelleColors.mauve,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
