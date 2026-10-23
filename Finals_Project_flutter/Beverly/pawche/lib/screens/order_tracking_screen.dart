import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/checkout_repository.dart';
import '../models/checkout.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/order_product_thumbnail.dart';

class OrderTrackingScreen extends StatefulWidget {
  final CheckoutOrder order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late CheckoutOrder _order = widget.order;
  bool _refreshing = false;
  bool _openingPayment = false;
  bool _loadingItems = true;
  String? _error;
  String? _itemsError;
  List<OrderHistoryItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _loadingItems = true;
      _itemsError = null;
    });
    try {
      final items = await CheckoutRepository.loadOrderItems(_order.id);
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _itemsError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingItems = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final refreshed = _order.paymentMethod == 'qrph'
          ? await CheckoutRepository.refreshQrphPayment(_order)
          : await CheckoutRepository.refreshOrder(_order);
      if (mounted) setState(() => _order = refreshed);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not refresh order status: $error');
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _openPayment() async {
    final value = _order.checkoutUrl;
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'checkout.paymongo.com') {
      setState(() {
        _error =
            'The secure PayMongo checkout link is unavailable. Refresh the order or contact support.';
      });
      return;
    }
    setState(() {
      _openingPayment = true;
      _error = null;
    });
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        setState(() => _error = 'Could not open the PayMongo checkout page.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not open checkout: $error');
    } finally {
      if (mounted) setState(() => _openingPayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = _order.paymentStatus == 'paid';
    final isCancelled = _order.status == 'cancelled';
    final isCod = _order.paymentMethod == 'cod';
    final title = isPaid
        ? 'Payment confirmed'
        : isCancelled
            ? 'Order cancelled'
            : isCod
                ? 'Order confirmed'
                : 'Payment pending';
    final statusCopy = isPaid
        ? 'PayMongo confirmed your payment. Your order is ready for processing.'
        : isCancelled
            ? 'This order is no longer active. Please return to your cart to place a new order.'
            : isCod
                ? 'Your order is saved. Pay the courier in cash when it arrives.'
                : 'Complete the payment in PayMongo. This page will show the confirmed status after you refresh.';

    return Scaffold(
      appBar: AppBar(title: const Text('Order status')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isPaid || isCod
                  ? const Color(0xFFEFF9F4)
                  : PawcheColors.blush,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isPaid || isCod
                      ? Icons.check_circle_outline_rounded
                      : isCancelled
                          ? Icons.cancel_outlined
                          : Icons.hourglass_top_rounded,
                  color: isPaid || isCod
                      ? PawcheColors.green
                      : PawcheColors.darkPink,
                  size: 30,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: PawcheColors.navy,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  statusCopy,
                  style: const TextStyle(
                    color: PawcheColors.navy,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _OrderRow('Order reference', _order.referenceNumber),
                  const SizedBox(height: 12),
                  _OrderRow('Payment method', _paymentMethod),
                  const SizedBox(height: 12),
                  _OrderRow(
                    'Payment status',
                    _label(_order.paymentStatus),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(),
                  ),
                  _OrderRow(
                    'Order total · delivery free',
                    formatPeso(_order.totalAmount),
                    emphasize: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Items in this order',
            style: TextStyle(
              color: PawcheColors.navy,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (_loadingItems)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Center(
                child: CircularProgressIndicator(color: PawcheColors.pink),
              ),
            )
          else if (_itemsError != null)
            Card(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(
                  Icons.cloud_off_rounded,
                  color: PawcheColors.darkPink,
                ),
                title: const Text('Order items could not be loaded'),
                subtitle: Text(_itemsError!),
                trailing: IconButton(
                  tooltip: 'Retry loading items',
                  onPressed: _loadItems,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
            )
          else if (_items.isEmpty)
            const Card(
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No item details were found for this order.',
                  style: TextStyle(color: PawcheColors.muted),
                ),
              ),
            )
          else
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (var index = 0; index < _items.length; index++) ...[
                      if (index > 0) const Divider(height: 18),
                      _OrderItemRow(item: _items[index]),
                    ],
                  ],
                ),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0EF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: PawcheColors.navy,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (!isCod && !isPaid && !isCancelled) ...[
            PinkButton(
              label: _openingPayment
                  ? 'Opening PayMongo…'
                  : 'Open secure PayMongo checkout',
              onPressed: _openingPayment ? null : _openPayment,
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label:
                Text(_refreshing ? 'Checking status…' : 'Refresh order status'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Payment status comes from your saved order and PayMongo confirmation, not from the return page.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: PawcheColors.muted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String get _paymentMethod =>
      _order.paymentMethod == 'qrph' ? 'PayMongo QRPH' : 'Cash on Delivery';

  String _label(String status) => switch (status) {
        'awaiting_payment' => 'Awaiting payment',
        'unpaid' => 'Pay on delivery',
        'paid' => 'Paid',
        'expired' => 'Expired',
        _ => status,
      };
}

class _OrderItemRow extends StatelessWidget {
  final OrderHistoryItem item;

  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          OrderProductThumbnail(item: item, size: 52),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PawcheColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.quantity} × ${formatPeso(item.unitPrice)}',
                  style: const TextStyle(
                    color: PawcheColors.muted,
                    fontSize: 12,
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
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
}

class _OrderRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _OrderRow(this.label, this.value, {this.emphasize = false});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: emphasize ? PawcheColors.navy : PawcheColors.muted,
                fontSize: 12,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: PawcheColors.navy,
              fontWeight: FontWeight.w800,
              fontSize: emphasize ? 17 : 13,
            ),
          ),
        ],
      );
}
