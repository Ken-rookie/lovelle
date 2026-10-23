import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/cart_store.dart';
import '../data/checkout_repository.dart';
import '../models/checkout.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'order_tracking_screen.dart';
import 'shop_screen.dart';

class PaymentScreen extends StatefulWidget {
  final int total;
  final List<CheckoutLineItem> lineItems;
  final DeliveryDetails? delivery;
  final bool consumeCartItems;

  const PaymentScreen({
    super.key,
    this.total = 3,
    this.lineItems = const [],
    this.delivery,
    this.consumeCartItems = false,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const _cod = 'cod';
  static const _qrph = 'qrph';

  String method = _cod;
  final String _requestId = CheckoutRepository.newRequestId();
  bool _submitting = false;
  String? _error;

  Future<void> _placeOrder() async {
    final delivery = widget.delivery;
    if (delivery == null || widget.lineItems.isEmpty) {
      setState(() {
        _error =
            'Return to checkout and enter delivery details before placing your order.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final order = await CheckoutRepository.createOrder(
        items: widget.lineItems,
        delivery: delivery,
        paymentMethod: method,
        requestId: _requestId,
      );
      if (widget.consumeCartItems) {
        CartStore.instance.consume({
          for (final item in widget.lineItems) item.productSlug: item.quantity,
        });
      }
      if (!mounted) return;
      if (method == _qrph) {
        final result = await showDialog<_QrphPaymentResult>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _QrphPaymentDialog(order: order),
        );
        if (!mounted || result == null) return;
        if (result.continueShopping) {
          await Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const ShopScreen()),
            (route) => route.isFirst,
          );
          return;
        }
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(order: result.order),
          ),
        );
        return;
      }
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: order)),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = _readableError(error));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _readableError(Object error) {
    final text =
        error.toString().replaceFirst(RegExp(r'^(Exception|StateError): '), '');
    if (text.contains('FunctionException') ||
        text.contains('FunctionsHttpException') ||
        text.contains('FunctionsRelayException')) {
      final detail = RegExp(
        r'details: \{[^}]*error:\s*([^,}]+)',
      ).firstMatch(text)?.group(1);
      if (detail != null) return detail.trim().replaceAll('"', '');
      return 'Checkout service error: $text';
    }
    if (text.contains('FunctionsFetchException')) {
      return 'Could not reach the live checkout service. Check your connection and try again.';
    }
    if (text.contains('Failed to fetch') || text.contains('SocketException')) {
      return 'Could not reach live checkout. Check your connection and confirm the Supabase checkout function is deployed.';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Payment')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const _PaymentProgress(),
            const SizedBox(height: 20),
            const Text(
              'Choose how to pay',
              style: TextStyle(
                color: PawcheColors.navy,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your order and total will be confirmed by the live checkout service.',
              style: TextStyle(color: PawcheColors.muted, height: 1.4),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [PawcheColors.blush, Color(0xFFFFF2F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: PawcheColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: PawcheColors.darkPink,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated order total',
                          style: TextStyle(
                            color: PawcheColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Free delivery · verified at checkout',
                          style: TextStyle(
                            color: PawcheColors.navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatPeso(widget.total),
                    style: const TextStyle(
                      color: PawcheColors.darkPink,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('PAYMENT METHOD'),
            const SizedBox(height: 9),
            _PaymentOption(
              title: 'Cash on Delivery (COD)',
              subtitle:
                  'Pay the delivery rider in cash when your order arrives.',
              icon: Icons.local_shipping_outlined,
              selected: method == _cod,
              badge: 'Pay on delivery',
              onTap: _submitting ? null : () => setState(() => method = _cod),
            ),
            const SizedBox(height: 10),
            _PaymentOption(
              title: 'PayMongo QRPH',
              subtitle:
                  'Scan a one-time QR with a supported bank or e-wallet. Payment is checked automatically.',
              icon: Icons.qr_code_2_rounded,
              selected: method == _qrph,
              badge: 'One-time QR · 5 minutes',
              onTap: _submitting ? null : () => setState(() => method = _qrph),
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _PaymentExplanation(
                key: ValueKey(method),
                isQrph: method == _qrph,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0EF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: PawcheColors.darkPink,
                      size: 19,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: PawcheColors.navy,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            PinkButton(
              label: _submitting
                  ? method == _qrph
                      ? 'Preparing your QRPH code…'
                      : 'Creating secure order…'
                  : method == _cod
                      ? 'Place COD order'
                      : 'Show PayMongo QR',
              onPressed: _submitting ? null : _placeOrder,
            ),
            if (_submitting) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 8),
            const Text(
              'The app never stores payment credentials. QRPH payment status is confirmed by PayMongo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: PawcheColors.muted, fontSize: 11),
            ),
          ],
        ),
      );
}

class _QrphPaymentResult {
  final CheckoutOrder order;
  final bool continueShopping;

  const _QrphPaymentResult({
    required this.order,
    this.continueShopping = false,
  });
}

class _QrphPaymentDialog extends StatefulWidget {
  final CheckoutOrder order;

  const _QrphPaymentDialog({required this.order});

  @override
  State<_QrphPaymentDialog> createState() => _QrphPaymentDialogState();
}

class _QrphPaymentDialogState extends State<_QrphPaymentDialog> {
  late CheckoutOrder _order = widget.order;
  late DateTime _expiresAt =
      widget.order.expiresAt ?? DateTime.now().add(const Duration(minutes: 5));
  late final Widget _qrImage;
  final ValueNotifier<int> _remainingSeconds = ValueNotifier<int>(300);
  Timer? _clock;
  Timer? _poller;
  bool _manualChecking = false;
  bool _statusCheckDelayed = false;

  bool get _paid => _order.paymentStatus == 'paid';
  bool get _expired =>
      _order.paymentStatus == 'expired' || _order.status == 'cancelled';

  @override
  void initState() {
    super.initState();
    _qrImage = _buildQrCode(widget.order.qrImageUrl);
    _remainingSeconds.value =
        _expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 300);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      _remainingSeconds.value =
          _expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 300);
    });
    _poller = Timer.periodic(const Duration(seconds: 5), (_) => _checkStatus());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _poller?.cancel();
    _remainingSeconds.dispose();
    super.dispose();
  }

  Future<void> _checkStatus({bool manual = false}) async {
    if (_manualChecking || _paid || _expired) return;
    if (manual) setState(() => _manualChecking = true);
    try {
      final refreshed = await CheckoutRepository.refreshQrphPayment(_order);
      if (!mounted) return;
      final statusChanged = refreshed.paymentStatus != _order.paymentStatus ||
          refreshed.status != _order.status;
      final expiryChanged =
          refreshed.expiresAt != null && refreshed.expiresAt != _expiresAt;
      if (statusChanged || expiryChanged || _statusCheckDelayed) {
        setState(() {
          _order = refreshed;
          _expiresAt = refreshed.expiresAt ?? _expiresAt;
          _statusCheckDelayed = false;
        });
      }
      if (refreshed.paymentStatus == 'paid' ||
          refreshed.paymentStatus == 'expired' ||
          refreshed.status == 'cancelled') {
        _poller?.cancel();
        _clock?.cancel();
      }
    } catch (_) {
      if (mounted && !_statusCheckDelayed) {
        setState(() => _statusCheckDelayed = true);
      }
    } finally {
      if (mounted && manual) setState(() => _manualChecking = false);
    }
  }

  Widget _buildQrCode(String? image) {
    if (image == null || image.isEmpty) {
      return const _QrUnavailable();
    }

    final base64Marker = image.indexOf('base64,');
    final encoded = base64Marker >= 0
        ? image.substring(base64Marker + 'base64,'.length)
        : image;
    try {
      final bytes = base64Decode(encoded);
      return Image.memory(
        bytes,
        width: 224,
        height: 224,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _QrUnavailable(),
      );
    } on FormatException {
      final uri = Uri.tryParse(image);
      if (uri == null || uri.scheme != 'https') return const _QrUnavailable();
      return Image.network(
        image,
        width: 224,
        height: 224,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _QrUnavailable(),
      );
    }
  }

  String _formatCountdown(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  @override
  Widget build(BuildContext context) {
    final finished = _paid || _expired;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
          maxWidth: 430,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Pay with QRPH',
                      style: TextStyle(
                        color: PawcheColors.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close and check later',
                    onPressed: () => Navigator.pop(
                      context,
                      _QrphPaymentResult(order: _order),
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                _paid
                    ? 'Payment confirmed'
                    : _expired
                        ? 'QR payment expired'
                        : 'Scan this code to pay',
                style: const TextStyle(
                  color: PawcheColors.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: 248,
                height: 248,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: PawcheColors.border),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: _qrImage,
              ),
              const SizedBox(height: 14),
              Text(
                formatPeso(_order.totalAmount),
                style: const TextStyle(
                  color: PawcheColors.darkPink,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Order ${_order.referenceNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: PawcheColors.muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              if (!finished) ...[
                ValueListenableBuilder<int>(
                  valueListenable: _remainingSeconds,
                  builder: (context, secondsLeft, _) => Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 19,
                            color: PawcheColors.darkPink,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'QR expires in ${_formatCountdown(secondsLeft)}',
                            style: const TextStyle(
                              color: PawcheColors.navy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: secondsLeft / 300,
                          minHeight: 7,
                          backgroundColor: PawcheColors.blush,
                          color: PawcheColors.pink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Payment is checked securely in the background. Keep this screen open until it is confirmed.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: PawcheColors.muted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ] else
                Text(
                  _paid
                      ? 'PayMongo confirmed your payment. Your order is ready.'
                      : 'The QR expired before payment was confirmed. You can return to your cart and place a new order.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: PawcheColors.navy,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              if (_statusCheckDelayed && !finished) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0EF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Payment status is taking longer to update. We’ll keep checking automatically.',
                    style: const TextStyle(
                      color: PawcheColors.navy,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _manualChecking || finished
                      ? null
                      : () => _checkStatus(manual: true),
                  icon: _manualChecking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    _manualChecking ? 'Checking…' : 'Check payment now',
                  ),
                ),
              ),
              if (_paid) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(
                          context,
                          _QrphPaymentResult(
                            order: _order,
                            continueShopping: true,
                          ),
                        ),
                        child: const Text('Continue shopping'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(
                          context,
                          _QrphPaymentResult(order: _order),
                        ),
                        child: const Text('View order'),
                      ),
                    ),
                  ],
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _QrphPaymentResult(order: _order),
                    ),
                    child: Text(
                      finished ? 'View order status' : 'Close and check later',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrUnavailable extends StatelessWidget {
  const _QrUnavailable();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_2_rounded,
              size: 52,
              color: PawcheColors.muted,
            ),
            SizedBox(height: 8),
            Text(
              'The QR image is unavailable. Retry or contact support before paying.',
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

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          color: PawcheColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
        ),
      );
}

class _PaymentOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _PaymentOption({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? const Color(0xFFFFF1F5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? PawcheColors.pink : PawcheColors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : PawcheColors.pale,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: PawcheColors.darkPink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: PawcheColors.navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: PawcheColors.muted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: PawcheColors.darkPink,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected ? PawcheColors.pink : PawcheColors.muted,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _PaymentExplanation extends StatelessWidget {
  final bool isQrph;

  const _PaymentExplanation({super.key, required this.isQrph});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isQrph ? const Color(0xFFF0F5FF) : const Color(0xFFEFF9F4),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isQrph ? Icons.qr_code_rounded : Icons.payments_outlined,
              color: isQrph ? PawcheColors.navy : PawcheColors.green,
              size: 19,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                isQrph
                    ? 'A unique QRPH code will appear here for 5 minutes. Keep this screen open; payment is checked every 5 seconds.'
                    : 'Your order is saved immediately. Pay the courier when it is delivered.',
                style: const TextStyle(
                  color: PawcheColors.navy,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
}

class _PaymentProgress extends StatelessWidget {
  const _PaymentProgress();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          _ProgressStep(number: '1', label: 'Shipping', complete: true),
          Expanded(child: Divider(color: PawcheColors.pink)),
          _ProgressStep(number: '2', label: 'Payment', active: true),
          Expanded(child: Divider()),
          _ProgressStep(number: '3', label: 'Review'),
        ],
      );
}

class _ProgressStep extends StatelessWidget {
  final String number;
  final String label;
  final bool active;
  final bool complete;

  const _ProgressStep({
    required this.number,
    required this.label,
    this.active = false,
    this.complete = false,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor:
                active || complete ? PawcheColors.pink : PawcheColors.blush,
            child: complete
                ? const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 16,
                  )
                : Text(
                    number,
                    style: TextStyle(
                      color: active ? Colors.white : PawcheColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: active ? PawcheColors.darkPink : PawcheColors.muted,
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      );
}
