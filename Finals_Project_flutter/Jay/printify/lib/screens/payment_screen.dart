import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../widgets/primary_button.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.amount,
  });

  final String orderId;
  final String orderNumber;
  final double amount;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _service = SupabaseService();
  bool _creatingQr = false;
  bool _selectingWalkIn = false;
  bool _paymentConfirmed = false;
  bool _walkInSelected = false;
  String? _error;

  Future<void> _createQrPayment() async {
    setState(() {
      _creatingQr = true;
      _error = null;
    });
    try {
      final data = await _service.createQrPhPayment(
        orderId: widget.orderId,
        amount: widget.amount,
      );
      final qrImage = data['qr_code']?.toString() ?? '';
      if (qrImage.isEmpty) {
        throw Exception('PayMongo did not return a QR image.');
      }
      if (!mounted) return;
      final status = await showDialog<String>(
        context: context,
        builder: (_) => QrPhPaymentDialog(
          orderId: widget.orderId,
          orderNumber: widget.orderNumber,
          amount: widget.amount,
          paymentId: data['payment_id']?.toString(),
          qrImage: qrImage,
          expiresAt: DateTime.tryParse(data['expires_at']?.toString() ?? ''),
          statusLoader: () => _service.getOrderPaymentStatus(widget.orderId),
        ),
      );
      if (mounted && status == 'paid') {
        setState(() => _paymentConfirmed = true);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingQr = false);
    }
  }

  Future<void> _selectWalkIn() async {
    setState(() {
      _selectingWalkIn = true;
      _error = null;
    });
    try {
      await _service.selectWalkInPayment(widget.orderId);
      if (mounted) setState(() => _walkInSelected = true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _selectingWalkIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payment',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Text(
                      'Order ${widget.orderNumber}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₱${widget.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0866F5),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_paymentConfirmed)
                      _message(
                        Icons.verified_outlined,
                        'Payment confirmed',
                        'PayMongo confirmed your payment for this order.',
                      )
                    else if (_walkInSelected)
                      _message(
                        Icons.storefront_outlined,
                        'Pay at the shop',
                        'Your order is awaiting payment. Show your order number '
                            'at the counter. It remains unpaid until staff confirm payment.',
                      )
                    else
                      _paymentOptions(),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Back to orders',
                      outlined: true,
                      onPressed: () =>
                          Navigator.popUntil(context, (route) => route.isFirst),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentOptions() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Choose how you want to pay',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 16),
      _PaymentChoice(
        icon: Icons.storefront_outlined,
        title: 'Walk-in payment',
        description: 'Pay at the print shop counter when you arrive.',
        buttonLabel: 'Choose walk-in',
        loading: _selectingWalkIn,
        onPressed: _selectWalkIn,
      ),
      const SizedBox(height: 12),
      _PaymentChoice(
        icon: Icons.qr_code_2,
        title: 'PayMongo QRPh',
        description: 'Pay online by scanning a QRPh code.',
        buttonLabel: 'Continue to QRPh',
        loading: _creatingQr,
        onPressed: _createQrPayment,
      ),
    ],
  );

  Widget _message(IconData icon, String title, String detail) => Column(
    children: [
      Icon(icon, color: const Color(0xFF0866F5), size: 48),
      const SizedBox(height: 8),
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      Text(
        detail,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.blueGrey),
      ),
    ],
  );
}

class _PaymentChoice extends StatelessWidget {
  const _PaymentChoice({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.loading,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0866F5), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(color: Colors.blueGrey)),
          const SizedBox(height: 12),
          PrimaryButton(
            label: buttonLabel,
            onPressed: loading ? null : onPressed,
            loading: loading,
          ),
        ],
      ),
    ),
  );
}

class QrPhPaymentDialog extends StatefulWidget {
  const QrPhPaymentDialog({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.amount,
    required this.qrImage,
    required this.statusLoader,
    this.paymentId,
    this.expiresAt,
  });

  final String orderId;
  final String orderNumber;
  final double amount;
  final String qrImage;
  final String? paymentId;
  final DateTime? expiresAt;
  final Future<String> Function() statusLoader;

  @override
  State<QrPhPaymentDialog> createState() => _QrPhPaymentDialogState();
}

class _QrPhPaymentDialogState extends State<QrPhPaymentDialog> {
  static const _checkInterval = Duration(seconds: 5);
  Timer? _timer;
  String _paymentStatus = 'pending';
  String? _checkError;
  bool _checkInProgress = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_checkInterval, (_) => _checkPayment());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkPayment() async {
    if (_checkInProgress || _isTerminal(_paymentStatus)) return;
    _checkInProgress = true;
    try {
      final nextStatus = await widget.statusLoader();
      if (!mounted) return;
      if (nextStatus != _paymentStatus || _checkError != null) {
        setState(() {
          _paymentStatus = nextStatus;
          _checkError = null;
        });
      }
      if (_isTerminal(nextStatus)) _timer?.cancel();
    } catch (_) {
      if (mounted) {
        const message =
            'Could not refresh payment status. Will retry automatically.';
        if (_checkError != message) setState(() => _checkError = message);
      }
    } finally {
      _checkInProgress = false;
    }
  }

  bool _isTerminal(String status) =>
      status == 'paid' || status == 'failed' || status == 'expired';

  String get _statusLabel {
    switch (_paymentStatus) {
      case 'paid':
        return 'Payment confirmed';
      case 'failed':
        return 'Payment failed';
      case 'expired':
        return 'QR code expired';
      default:
        return 'Waiting for payment';
    }
  }

  Color get _statusColor => _paymentStatus == 'paid'
      ? const Color(0xFF16834A)
      : const Color(0xFF0866F5);

  Uint8List? _decodeQrImage() {
    try {
      final imageData = widget.qrImage;
      if (imageData.startsWith('http://') || imageData.startsWith('https://')) {
        return null;
      }
      final content = imageData.startsWith('data:')
          ? imageData.split(',').last
          : imageData;
      return base64Decode(content);
    } on FormatException {
      return null;
    }
  }

  String _expiryLabel() {
    final expiresAt = widget.expiresAt;
    if (expiresAt == null) return 'QRPh codes usually expire after 30 minutes.';
    final local = expiresAt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour < 12 ? 'AM' : 'PM';
    return 'QR code expires at $hour:$minute $suffix.';
  }

  @override
  Widget build(BuildContext context) {
    final qrBytes = _decodeQrImage();
    final remote =
        widget.qrImage.startsWith('http://') ||
        widget.qrImage.startsWith('https://');
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.qr_code_2, color: Color(0xFF0866F5), size: 42),
              const SizedBox(height: 8),
              const Text(
                'Scan to pay with QRPh',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text('Order ${widget.orderNumber}'),
              const SizedBox(height: 4),
              Text(
                '₱${widget.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF0866F5),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: 248,
                height: 248,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE1EBF8)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: qrBytes != null
                    ? Image.memory(
                        qrBytes,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _invalidQr(),
                      )
                    : remote
                    ? Image.network(
                        widget.qrImage,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _invalidQr(),
                      )
                    : _invalidQr(),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F7FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      _statusLabel,
                      style: TextStyle(
                        color: _statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Keep this screen open. Payment status checks automatically every 5 seconds.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                    if (_checkError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _checkError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Open your bank or e-wallet app, choose Scan QR, and scan this code. '
                'Pay the exact amount shown above. Return here after payment; this screen '
                'will update when PayMongo confirms it.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                _expiryLabel(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
              if (widget.paymentId != null) ...[
                const SizedBox(height: 6),
                SelectableText(
                  'Payment reference: ${widget.paymentId}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
              ],
              const SizedBox(height: 14),
              PrimaryButton(
                label: _paymentStatus == 'paid' ? 'Done' : 'Close',
                onPressed: () => Navigator.pop(context, _paymentStatus),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _invalidQr() => const Center(
    child: Text('QR code could not be displayed. Please try again.'),
  );
}
