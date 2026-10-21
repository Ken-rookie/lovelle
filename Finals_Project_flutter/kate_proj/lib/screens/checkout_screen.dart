import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/paymongo_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'order_confirmation_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.cart});

  final List<Map<String, dynamic>> cart;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _giftRecipient = TextEditingController();
  final _message = TextEditingController();
  final Map<String, String> _roseTypes = {};
  String _fulfillment = 'delivery';
  bool _wrapping = false;
  bool _card = false;
  bool _busy = false;

  static const double wrappingFee = 1;
  static const double cardFee = 1;
  static const double deliveryFee = 1;

  String _paymentMethod = 'paymongo';

  double get subtotal => widget.cart.fold(0, (sum, row) {
        final product = Map<String, dynamic>.from(row['products'] as Map);
        return sum +
            (Product.normalizePrice(product['price'])) *
                (row['quantity'] as int);
      });

  List<Map<String, dynamic>> get _roseGiftRows => widget.cart.where((row) {
        final product = Map<String, dynamic>.from(row['products'] as Map);
        return product['is_rose_gift'] == true;
      }).toList();

  double get total =>
      subtotal +
      (_fulfillment == 'delivery' ? deliveryFee : 0) +
      (_wrapping ? wrappingFee : 0) +
      (_card ? cardFee : 0);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await SupabaseService.getProfile();
      if (profile == null || !mounted) return;
      _name.text = profile['full_name']?.toString() ?? '';
      _phone.text = profile['phone']?.toString() ?? '';
      final addressLine = profile['address_line']?.toString().trim() ?? '';
      final city = profile['city']?.toString().trim() ?? '';
      _address.text =
          [addressLine, city].where((part) => part.isNotEmpty).join(', ');
    } catch (error) {
      if (mounted) {
        showOperationError(context, error);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _giftRecipient.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!_form.currentState!.validate()) return;
    if (_roseGiftRows.any((row) {
      final product = Map<String, dynamic>.from(row['products'] as Map);
      return !_roseTypes.containsKey(product['id'].toString());
    })) {
      showMessage(context, 'Choose a rose style for each rose gift.');
      return;
    }
    setState(() => _busy = true);
    try {
      bool paid = true;
      String? paymentIntentId;
      if (_paymentMethod == 'paymongo') {
        final paymentSource = await PayMongoService.createQrPhSource(
          fulfillment: _fulfillment,
          wrapping: _wrapping,
          greetingCard: _card,
        );
        if (!mounted) return;

        paymentIntentId = paymentSource.id;
        final paymentAlreadySucceeded = {
          'succeeded',
          'paid',
          'completed',
        }.contains(paymentSource.status.toLowerCase());
        if (paymentAlreadySucceeded) {
          final continueWithPaidPayment = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Payment already completed'),
              content: const Text(
                'PayMongo reports that your previous payment succeeded, so no new QR will be created. Continue only if you recognize this payment. If you did not pay, cancel and check your payment account before trying again.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Continue'),
                ),
              ],
            ),
          );
          if (!mounted) return;
          if (continueWithPaidPayment != true) {
            showMessage(
              context,
              'No new QR was created. Check your payment account before trying again.',
            );
            return;
          }
        } else {
          final sourceDialog = _PayMongoDialogController();
          final dialogFuture = showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => _PayMongoQrDialog(controller: sourceDialog),
          );
          sourceDialog.updateSource(paymentSource);
          paid = await dialogFuture ?? false;
        }
      }

      if (!paid) {
        if (mounted) showMessage(context, 'Payment was not completed in time.');
        return;
      }

      final recipient = _giftRecipient.text.trim().isEmpty
          ? _name.text.trim()
          : _giftRecipient.text.trim();
      final address = _fulfillment == 'delivery' ? _address.text.trim() : '';
      final order = _paymentMethod == 'paymongo'
          ? await PayMongoService.finalizePaidOrder(
              paymentIntentId: paymentIntentId!,
              fulfillment: _fulfillment,
              recipient: recipient,
              phone: _phone.text.trim(),
              address: address,
              wrapping: _wrapping,
              greetingCard: _card,
              greetingMessage: _message.text.trim(),
              roseTypes: _roseTypes,
            )
          : await SupabaseService.placeOrder(
              recipient: recipient,
              phone: _phone.text.trim(),
              address: address,
              fulfillment: _fulfillment,
              paymentMethod: _paymentMethod,
              wrapping: _wrapping,
              greetingCard: _card,
              greetingMessage: _message.text.trim(),
              roseTypes: _roseTypes,
            );
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(order: order),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) showOperationError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: LayoutBuilder(
          builder: (context, constraints) => Form(
            key: _form,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: constraints.maxWidth > 760 ? 760 : constraints.maxWidth,
                height: constraints.maxHeight,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 22),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            LovelleColors.palePink,
                            LovelleColors.cream,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: LovelleColors.border),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.card_giftcard_rounded,
                            color: LovelleColors.roseDark,
                            size: 25,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You’re almost there',
                                  style: TextStyle(
                                    color: LovelleColors.plum,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Add your delivery details and make this gift personal.',
                                  style: TextStyle(
                                    color: LovelleColors.mauve,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'How would you like to receive it?',
                      style: TextStyle(
                        color: LovelleColors.plum,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'delivery',
                          label: Text('Delivery'),
                          icon: Icon(Icons.local_shipping_outlined),
                        ),
                        ButtonSegment(
                          value: 'pickup',
                          label: Text('Pickup'),
                          icon: Icon(Icons.storefront_outlined),
                        ),
                      ],
                      selected: {_fulfillment},
                      onSelectionChanged: (selection) =>
                          setState(() => _fulfillment = selection.first),
                    ),
                    if (_roseGiftRows.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _sectionTitle('Choose your rose style'),
                      const SizedBox(height: 6),
                      const Text(
                        'Pick a style for each rose gift. Both options have the same price.',
                        style: TextStyle(
                          color: LovelleColors.mauve,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._roseGiftRows.map((row) {
                        final product =
                            Map<String, dynamic>.from(row['products'] as Map);
                        final productId = product['id'].toString();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _RoseStylePicker(
                            productName:
                                product['name']?.toString() ?? 'Rose gift',
                            selected: _roseTypes[productId],
                            onChanged: (value) => setState(() {
                              _roseTypes[productId] = value;
                            }),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 22),
                    _sectionTitle('Contact details'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Your full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter your name'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter a contact number'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _giftRecipient,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Gift recipient (optional)',
                        hintText: 'Leave blank to use your name',
                        prefixIcon: Icon(Icons.card_giftcard_outlined),
                      ),
                    ),
                    if (_fulfillment == 'delivery') ...[
                      const SizedBox(height: 22),
                      _sectionTitle('Delivery address'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _address,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          hintText: 'House number, street, barangay, city',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) => _fulfillment == 'delivery' &&
                                (value == null || value.trim().isEmpty)
                            ? 'Enter a delivery address'
                            : null,
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: LovelleColors.palePink,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              color: LovelleColors.roseDark,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Pickup details will be shared with your order information when available.',
                                style: TextStyle(
                                  color: LovelleColors.plum,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _sectionTitle('Make it extra thoughtful'),
                    const SizedBox(height: 8),
                    _GiftOptionTile(
                      icon: Icons.redeem_rounded,
                      title: 'Gift wrapping',
                      description: peso.format(wrappingFee),
                      value: _wrapping,
                      onChanged: (value) => setState(() => _wrapping = value),
                    ),
                    const SizedBox(height: 8),
                    _GiftOptionTile(
                      icon: Icons.mail_outline_rounded,
                      title: 'Greeting card',
                      description: peso.format(cardFee),
                      value: _card,
                      onChanged: (value) => setState(() => _card = value),
                    ),
                    if (_card) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _message,
                        maxLength: 250,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Personal message (optional)',
                          hintText: 'Write a little note...',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _sectionTitle('Payment'),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'paymongo',
                          label: Text('PayMongo'),
                          icon: Icon(Icons.payments_outlined),
                        ),
                        ButtonSegment(
                          value: 'cash_on_delivery',
                          label: Text('Cash on delivery'),
                          icon: Icon(Icons.local_shipping_outlined),
                        ),
                      ],
                      selected: {_paymentMethod},
                      onSelectionChanged: (selection) =>
                          setState(() => _paymentMethod = selection.first),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Order summary'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: LovelleColors.border),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          ..._roseGiftRows.map((row) {
                            final product = Map<String, dynamic>.from(
                                row['products'] as Map);
                            final selected =
                                _roseTypes[product['id'].toString()];
                            return _summaryLabel(
                              '${product['name']} style',
                              selected == null
                                  ? 'Choose a style'
                                  : selected == 'fresh'
                                      ? 'Fresh rose'
                                      : 'Artificial rose',
                            );
                          }),
                          _summaryLine('Items subtotal', subtotal),
                          _summaryLine(
                            'Delivery',
                            _fulfillment == 'delivery' ? deliveryFee : 0,
                          ),
                          _summaryLine(
                            'Gift wrapping',
                            _wrapping ? wrappingFee : 0,
                          ),
                          _summaryLine('Greeting card', _card ? cardFee : 0),
                          const Divider(height: 24),
                          _summaryLine('Order total', total, isTotal: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: LovelleColors.border),
              ),
              boxShadow: [
                BoxShadow(
                  color: LovelleColors.plum.withValues(alpha: .06),
                  blurRadius: 14,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 724),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              color: LovelleColors.mauve,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            peso.format(total),
                            style: const TextStyle(
                              color: LovelleColors.roseDark,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _placeOrder,
                        child: _busy
                            ? const SizedBox(
                                width: 21,
                                height: 21,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Place order'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          color: LovelleColors.plum,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      );

  Widget _summaryLine(String label, double value, {bool isTotal = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isTotal ? LovelleColors.plum : LovelleColors.mauve,
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.normal,
              ),
            ),
            Text(
              peso.format(value),
              style: TextStyle(
                color: isTotal ? LovelleColors.roseDark : LovelleColors.plum,
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
                fontSize: isTotal ? 18 : 14,
              ),
            ),
          ],
        ),
      );

  Widget _summaryLabel(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: LovelleColors.mauve),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: const TextStyle(
                color: LovelleColors.plum,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _PayMongoDialogController {
  _PayMongoDialogController();

  final _completer = Completer<bool>();
  final ValueNotifier<_PayMongoDialogState> state = ValueNotifier(
    const _PayMongoDialogState(
      sourceId: '',
      qrCodeUrl: '',
      expiresAt: null,
      status: 'Preparing QR code...',
      isExpired: false,
    ),
  );

  Future<bool> get future => _completer.future;

  void updateSource(PayMongoPaymentSession paymentSource) {
    state.value = _PayMongoDialogState(
      sourceId: paymentSource.id,
      qrCodeUrl: paymentSource.qrCodeUrl,
      expiresAt: paymentSource.expiresAt,
      status: 'Waiting for payment...',
      isExpired: false,
    );
  }

  void setStatus(String status) {
    final current = state.value;
    state.value = current.copyWith(status: status);
  }

  void expire() {
    final current = state.value;
    state.value = current.copyWith(isExpired: true, status: 'Payment expired');
    if (!_completer.isCompleted) _completer.complete(false);
  }

  void complete(bool paid) {
    if (!_completer.isCompleted) _completer.complete(paid);
  }
}

class _PayMongoDialogState {
  const _PayMongoDialogState({
    required this.sourceId,
    required this.qrCodeUrl,
    required this.expiresAt,
    required this.status,
    required this.isExpired,
  });

  final String sourceId;
  final String qrCodeUrl;
  final DateTime? expiresAt;
  final String status;
  final bool isExpired;

  _PayMongoDialogState copyWith({
    String? sourceId,
    String? qrCodeUrl,
    DateTime? expiresAt,
    String? status,
    bool? isExpired,
  }) =>
      _PayMongoDialogState(
        sourceId: sourceId ?? this.sourceId,
        qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
        expiresAt: expiresAt ?? this.expiresAt,
        status: status ?? this.status,
        isExpired: isExpired ?? this.isExpired,
      );
}

class _PayMongoQrDialog extends StatefulWidget {
  const _PayMongoQrDialog({required this.controller});

  final _PayMongoDialogController controller;

  @override
  State<_PayMongoQrDialog> createState() => _PayMongoQrDialogState();
}

class _PayMongoQrDialogState extends State<_PayMongoQrDialog> {
  Timer? _timer;
  bool _checkingStatus = false;

  @override
  void initState() {
    super.initState();
    widget.controller.state.addListener(_handleStateChange);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _pollStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.state.removeListener(_handleStateChange);
    super.dispose();
  }

  void _handleStateChange() {
    if (!mounted) return;
    final current = widget.controller.state.value;
    if (current.isExpired && !Navigator.of(context).canPop()) {
      return;
    }
    if (current.isExpired) {
      Navigator.of(context).pop(false);
    }
    setState(() {});
  }

  Future<void> _pollStatus() async {
    if (_checkingStatus) return;
    final current = widget.controller.state.value;
    if (current.sourceId.isEmpty || current.expiresAt == null) {
      return;
    }

    final remaining = current.expiresAt!.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      widget.controller.expire();
      return;
    }

    _checkingStatus = true;
    try {
      final status = await PayMongoService.checkSourceStatus(current.sourceId);
      if (status == 'paid' || status == 'completed' || status == 'succeeded') {
        widget.controller.complete(true);
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      if (status == 'expired' ||
          status == 'failed' ||
          status == 'canceled' ||
          status == 'requires_payment_method') {
        widget.controller.expire();
        return;
      }
      widget.controller.setStatus('Waiting for payment...');
    } catch (_) {
      widget.controller.setStatus('Checking payment...');
    } finally {
      _checkingStatus = false;
    }
  }

  Widget _buildQrImage(String imageUrl) {
    Uint8List? bytes;
    try {
      final data = Uri.tryParse(imageUrl)?.data;
      if (data != null) {
        bytes = data.contentAsBytes();
      } else if (RegExp(r'^[A-Za-z0-9+/=\r\n]+$').hasMatch(imageUrl)) {
        bytes = base64Decode(imageUrl);
      }
    } on FormatException {
      bytes = null;
    }
    if (bytes != null) {
      return Image.memory(
        bytes,
        width: 180,
        height: 180,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.qr_code_2_rounded,
          size: 120,
          color: LovelleColors.roseDark,
        ),
      );
    }
    return Image.network(
      imageUrl,
      width: 180,
      height: 180,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.qr_code_2_rounded,
        size: 120,
        color: LovelleColors.roseDark,
      ),
    );
  }

  String _remainingTime() {
    final expiresAt = widget.controller.state.value.expiresAt;
    if (expiresAt == null) return '00:00';
    final remaining = expiresAt.difference(DateTime.now());
    final totalSeconds = remaining.inSeconds.clamp(0, 300);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.controller.state.value;
    final hasQr = current.qrCodeUrl.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('PayMongo QR payment'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scan this QR code within 5 minutes. The app checks every 5 seconds.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: LovelleColors.mauve),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: LovelleColors.border),
              ),
              child: hasQr
                  ? _buildQrImage(current.qrCodeUrl)
                  : const Icon(
                      Icons.qr_code_2_rounded,
                      size: 120,
                      color: LovelleColors.roseDark,
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              current.isExpired
                  ? 'Payment expired'
                  : 'Time remaining: ${_remainingTime()}',
              style: const TextStyle(
                color: LovelleColors.roseDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              current.status,
              style: const TextStyle(color: LovelleColors.mauve),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.controller.complete(false);
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(false);
            }
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _RoseStylePicker extends StatelessWidget {
  const _RoseStylePicker({
    required this.productName,
    required this.selected,
    required this.onChanged,
  });

  final String productName;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: LovelleColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              productName,
              style: const TextStyle(
                color: LovelleColors.plum,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: selected,
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
              child: Column(
                children: [
                  _RoseStyleOption(
                    value: 'fresh',
                    selected: selected,
                    title: 'Fresh rose',
                    description: 'A real rose with natural petals.',
                    icon: Icons.local_florist_outlined,
                    onChanged: onChanged,
                  ),
                  const SizedBox(height: 8),
                  _RoseStyleOption(
                    value: 'artificial',
                    selected: selected,
                    title: 'Artificial rose',
                    description: 'A lasting keepsake that needs no watering.',
                    icon: Icons.auto_awesome_outlined,
                    onChanged: onChanged,
                  ),
                ],
              ),
            ),
            if (selected == null) ...[
              const SizedBox(height: 6),
              const Text(
                'Please choose one option.',
                style: TextStyle(
                  color: LovelleColors.roseDark,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      );
}

class _RoseStyleOption extends StatelessWidget {
  const _RoseStyleOption({
    required this.value,
    required this.selected,
    required this.title,
    required this.description,
    required this.icon,
    required this.onChanged,
  });

  final String value;
  final String? selected;
  final String title;
  final String description;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return Material(
      color: isSelected ? LovelleColors.palePink : LovelleColors.blush,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: LovelleColors.roseDark),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: LovelleColors.plum,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      description,
                      style: const TextStyle(
                        color: LovelleColors.mauve,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Radio<String>(value: value),
            ],
          ),
        ),
      ),
    );
  }
}

class _GiftOptionTile extends StatelessWidget {
  const _GiftOptionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: CheckboxListTile(
          value: value,
          onChanged: (next) => onChanged(next ?? false),
          controlAffinity: ListTileControlAffinity.trailing,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: LovelleColors.border),
          ),
          secondary: Icon(icon, color: LovelleColors.rose),
          title: Text(
            title,
            style: const TextStyle(
              color: LovelleColors.plum,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(description),
        ),
      );
}
