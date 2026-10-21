import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/order_status_summary.dart';
import 'order_tracking_screen.dart';

class OrderConfirmationScreen extends StatefulWidget {
  const OrderConfirmationScreen({super.key, required this.order});

  final Map<String, dynamic> order;

  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final roseItems = (order['order_items'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => item['rose_type'] != null);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  ScaleTransition(
                    scale: _scale,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6F2E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: LovelleColors.sage,
                        size: 58,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Order confirmed',
                    style: TextStyle(
                      color: LovelleColors.plum,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Thank you for choosing a thoughtful gift. We’ve saved your order.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: LovelleColors.mauve,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: LovelleColors.border),
                    ),
                    child: Column(
                      children: [
                        _row(
                          'Order number',
                          order['order_number']?.toString() ?? 'Pending',
                        ),
                        _row(
                          'Order total',
                          peso.format(
                            double.tryParse(order['total_amount'].toString()) ??
                                0,
                          ),
                        ),
                        _row(
                          'Fulfillment',
                          order['fulfillment_method'] == 'pickup'
                              ? 'Pickup'
                              : 'Delivery',
                        ),
                        ...roseItems.map(
                          (item) => _row(
                            '${item['product_name'] ?? 'Rose gift'} style',
                            item['rose_type'] == 'fresh'
                                ? 'Fresh rose'
                                : 'Artificial rose',
                          ),
                        ),
                        const SizedBox(height: 12),
                        OrderStatusSummary(
                          orderStatus: order['status']?.toString(),
                          paymentStatus: order['payment_status']?.toString(),
                          paymentMethod: order['payment_method']?.toString(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Continue shopping'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => OrderTrackingScreen(order: order),
                      ),
                    ),
                    child: const Text('View order status'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: LovelleColors.mauve)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: LovelleColors.plum,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}
