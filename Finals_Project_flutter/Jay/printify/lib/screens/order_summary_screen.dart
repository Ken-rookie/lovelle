import 'package:flutter/material.dart';
import '../models/print_order.dart';
import '../services/supabase_service.dart';
import '../widgets/primary_button.dart';
import 'payment_screen.dart';

class OrderSummaryScreen extends StatefulWidget {
  const OrderSummaryScreen({super.key, required this.draft});
  final PrintOrderDraft draft;

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  bool busy = false;
  final service = SupabaseService();

  Future<void> proceed() async {
    setState(() => busy = true);
    try {
      final result = await service.createOrder(widget.draft);
      final orderId = (result['order_id'] ?? result['id'] ?? '').toString();
      final orderNumber = (result['order_number'] ?? orderId).toString();
      final amount =
          (result['total'] as num?)?.toDouble() ?? widget.draft.subtotal;
      if (orderId.isEmpty) {
        throw Exception('Order function did not return order_id.');
      }
      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            orderId: orderId,
            orderNumber: orderNumber,
            amount: amount,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Order summary',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Review before you proceed',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line('Service', d.service),
                  _line('Paper size', d.paperSize),
                  _line('Orientation', d.orientation),
                  _line('Color mode', d.colorMode),
                  _line('Sides', d.sides),
                  _line('Paper type', d.paperType),
                  _line('Copies per file', '${d.copies}'),
                  const Divider(height: 24),
                  const Text(
                    'Files',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  ...d.files.map(
                    (f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.description_outlined,
                            color: Color(0xFF0866F5),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              f.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(f.readableSize),
                        ],
                      ),
                    ),
                  ),
                  if (d.notes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('Notes: ${d.notes}'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _line(
                    'Subtotal (estimate)',
                    '₱${d.subtotal.toStringAsFixed(2)}',
                  ),
                  _line('Delivery / service fee', 'Calculated by server'),
                  const Divider(),
                  const Text(
                    'Final price is calculated securely by the backend.',
                    style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'After creating your order, choose walk-in payment or PayMongo QRPh.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Create order & choose payment',
            icon: Icons.payments_outlined,
            onPressed: proceed,
            loading: busy,
          ),
        ],
      ),
    );
  }

  Widget _line(String a, String b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(a, style: const TextStyle(color: Colors.blueGrey)),
        ),
        Flexible(
          child: Text(
            b,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
