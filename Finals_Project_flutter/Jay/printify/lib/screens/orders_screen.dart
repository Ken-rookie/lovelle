import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final service = SupabaseService();
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = service.getMyOrders();
  }

  Future<void> refresh() async {
    final nextOrders = service.getMyOrders();
    setState(() => future = nextOrders);
    try {
      await nextOrders;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh orders: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My orders',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh orders',
            onPressed: refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Center(child: CircularProgressIndicator()),
                  SizedBox(height: 16),
                  Center(child: Text('Loading your orders...')),
                ],
              );
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 100),
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 54,
                    color: Color(0xFF8AA9D3),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Orders could not be loaded',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check your connection and try again.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: FilledButton.icon(
                      onPressed: refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ),
                ],
              );
            }

            final orders = snapshot.data ?? [];
            if (orders.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(30),
                children: const [
                  SizedBox(height: 70),
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Color(0xFF8AA9D3),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No orders yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'When you submit a print order, its payment and progress will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: orders.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
                    child: Text(
                      'Check payment and print progress for your submitted orders.',
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                  );
                }
                return OrderHistoryCard(order: orders[index - 1]);
              },
            );
          },
        ),
      ),
    );
  }
}

class OrderHistoryCard extends StatelessWidget {
  const OrderHistoryCard({super.key, required this.order});

  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final number = (order['order_number'] ?? order['id'] ?? 'Print order')
        .toString();
    final service = (order['service_type'] ?? 'Documents').toString();
    final status = _orderStatus(order['status']?.toString());
    final payment = _paymentStatus(order['payment_status']?.toString());
    final amount = _amountLabel(order['total'] ?? order['subtotal']);
    final date = _dateLabel(order['created_at']?.toString());
    final copies = order['copies'];
    final files = _orderFiles(order['print_order_files']);
    final details = <(String, String)>[
      if (order['paper_size'] != null)
        ('Paper size', order['paper_size'].toString()),
      if (order['orientation'] != null)
        ('Orientation', order['orientation'].toString()),
      if (order['color_mode'] != null)
        ('Color mode', order['color_mode'].toString()),
      if (order['print_sides'] != null)
        ('Print sides', order['print_sides'].toString()),
      if (order['paper_type'] != null)
        ('Paper type', order['paper_type'].toString()),
      if (copies is num) ('Copies per file', copies.toInt().toString()),
    ];
    final notes = (order['notes'] ?? '').toString().trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFE5F1FF),
                  child: const Icon(
                    Icons.print_outlined,
                    color: Color(0xFF0866F5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        number,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        service,
                        style: const TextStyle(color: Colors.blueGrey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  amount,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusBadge(
                  icon: status.icon,
                  label: status.label,
                  color: status.color,
                ),
                _StatusBadge(
                  icon: payment.icon,
                  label: payment.label,
                  color: payment.color,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              status.description,
              style: const TextStyle(fontSize: 13, color: Color(0xFF43566E)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.schedule_outlined,
                  size: 16,
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    date,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
                if (copies is num)
                  Text(
                    '${copies.toInt()} ${copies == 1 ? 'copy' : 'copies'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
                    ),
                  ),
              ],
            ),
            if (files.isNotEmpty || details.isNotEmpty || notes.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: const Text(
                  'Print job details',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                subtitle: Text(
                  files.isEmpty
                      ? 'View print settings'
                      : '${files.length} ${files.length == 1 ? 'file' : 'files'} to print',
                ),
                leading: const Icon(
                  Icons.description_outlined,
                  color: Color(0xFF0866F5),
                ),
                children: [
                  if (files.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Files submitted',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    ...files.map(_fileDetail),
                    if (details.isNotEmpty) const Divider(height: 20),
                  ] else
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          'No file details were saved for this order.',
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ),
                    ),
                  ...details.map((detail) => _detailRow(detail.$1, detail.$2)),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _detailRow('Notes', notes),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  static List<Map<String, dynamic>> _orderFiles(Object? value) {
    if (value is! List) return const [];
    return value.whereType<Map<String, dynamic>>().toList();
  }

  static Widget _fileDetail(Map<String, dynamic> file) {
    final name = (file['file_name'] ?? 'Unnamed file').toString();
    final extension = (file['file_extension'] ?? '').toString().toUpperCase();
    final bytes = file['file_size_bytes'];
    final pageCount = file['page_count'];
    final description = <String>[
      if (extension.isNotEmpty) extension,
      if (bytes is num) _readableSize(bytes.toInt()),
      if (pageCount is num && pageCount > 0)
        '${pageCount.toInt()} ${pageCount == 1 ? 'page' : 'pages'}',
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.insert_drive_file_outlined,
            size: 18,
            color: Color(0xFF0866F5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _readableSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  static Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(label, style: const TextStyle(color: Colors.blueGrey)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  static String _amountLabel(Object? value) {
    if (value is num) return '₱${value.toStringAsFixed(2)}';
    return 'Amount unavailable';
  }

  static String _dateLabel(String? value) {
    final date = value == null ? null : DateTime.tryParse(value)?.toLocal();
    if (date == null) return 'Date unavailable';

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
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour < 12 ? 'AM' : 'PM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} • $hour:$minute $suffix';
  }

  static _StatusPresentation _orderStatus(String? value) {
    switch (value) {
      case 'awaiting_payment':
        return const _StatusPresentation(
          label: 'Awaiting payment',
          description: 'Payment is needed before the shop can start printing.',
          icon: Icons.pending_actions_outlined,
          color: Color(0xFF9A5B00),
        );
      case 'paid':
        return const _StatusPresentation(
          label: 'Paid',
          description:
              'Payment is confirmed. Your order is with the print shop.',
          icon: Icons.verified_outlined,
          color: Color(0xFF16834A),
        );
      case 'received':
        return const _StatusPresentation(
          label: 'Received by shop',
          description: 'The shop has received your order.',
          icon: Icons.inventory_2_outlined,
          color: Color(0xFF0866F5),
        );
      case 'printing':
        return const _StatusPresentation(
          label: 'Printing',
          description: 'The shop is printing your order.',
          icon: Icons.print_outlined,
          color: Color(0xFF0866F5),
        );
      case 'quality_check':
        return const _StatusPresentation(
          label: 'Quality check',
          description: 'The shop is checking your prints.',
          icon: Icons.fact_check_outlined,
          color: Color(0xFF0866F5),
        );
      case 'ready':
        return const _StatusPresentation(
          label: 'Ready',
          description: 'Your order is ready for pickup.',
          icon: Icons.shopping_bag_outlined,
          color: Color(0xFF16834A),
        );
      case 'completed':
        return const _StatusPresentation(
          label: 'Completed',
          description: 'This order has been completed.',
          icon: Icons.check_circle_outline,
          color: Color(0xFF16834A),
        );
      case 'cancelled':
        return const _StatusPresentation(
          label: 'Cancelled',
          description: 'This order was cancelled.',
          icon: Icons.cancel_outlined,
          color: Color(0xFFB42318),
        );
      case 'failed':
        return const _StatusPresentation(
          label: 'Needs attention',
          description: 'There was a problem with this order. Contact the shop.',
          icon: Icons.error_outline,
          color: Color(0xFFB42318),
        );
      case 'pending':
      default:
        return const _StatusPresentation(
          label: 'Order received',
          description: 'Your order has been submitted.',
          icon: Icons.receipt_long_outlined,
          color: Color(0xFF0866F5),
        );
    }
  }

  static _StatusPresentation _paymentStatus(String? value) {
    switch (value) {
      case 'paid':
        return const _StatusPresentation(
          label: 'Payment confirmed',
          icon: Icons.check_circle_outline,
          color: Color(0xFF16834A),
        );
      case 'pending':
        return const _StatusPresentation(
          label: 'Payment processing',
          icon: Icons.hourglass_top,
          color: Color(0xFF9A5B00),
        );
      case 'failed':
        return const _StatusPresentation(
          label: 'Payment failed',
          icon: Icons.error_outline,
          color: Color(0xFFB42318),
        );
      case 'expired':
        return const _StatusPresentation(
          label: 'Payment expired',
          icon: Icons.timer_off_outlined,
          color: Color(0xFF9A5B00),
        );
      case 'refunded':
        return const _StatusPresentation(
          label: 'Refunded',
          icon: Icons.undo_outlined,
          color: Color(0xFF0866F5),
        );
      case 'unpaid':
      default:
        return const _StatusPresentation(
          label: 'Not paid',
          icon: Icons.payments_outlined,
          color: Color(0xFF9A5B00),
        );
    }
  }
}

class _StatusPresentation {
  const _StatusPresentation({
    required this.label,
    required this.icon,
    required this.color,
    this.description = '',
  });

  final String label;
  final String description;
  final IconData icon;
  final Color color;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
