import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_service.dart';
import '../data/bohol_address_repository.dart';
import '../data/checkout_repository.dart';
import '../models/checkout.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'payment_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final int subtotal;
  final int shipping;
  final int itemCount;
  final List<CheckoutLineItem> lineItems;
  final bool removePurchasedItemsFromCart;

  const CheckoutScreen({
    super.key,
    this.subtotal = 3,
    this.shipping = 0,
    this.itemCount = 3,
    this.lineItems = const [],
    this.removePurchasedItemsFromCart = false,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _phone;
  final _addressLine1 = TextEditingController();
  final _addressLine2 = TextEditingController();
  final _postalCode = TextEditingController();
  final _deliveryNote = TextEditingController();
  bool _loadingSavedAddress = true;
  bool _loadingLocations = true;
  String? _addressLoadError;
  String? _locationsError;
  Map<String, List<String>> _locations = {};
  String? _municipality;
  String? _barangay;

  @override
  void initState() {
    super.initState();
    final user = SupabaseService.initializedClient?.auth.currentUser;
    _fullName = TextEditingController(
      text: user?.userMetadata?['full_name'] as String? ?? '',
    );
    _phone = TextEditingController(
      text: user?.userMetadata?['phone'] as String? ?? '',
    );
    _loadLocations();
    _loadSavedAddress();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _addressLine1.dispose();
    _addressLine2.dispose();
    _postalCode.dispose();
    _deliveryNote.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAddress() async {
    try {
      final saved = await CheckoutRepository.loadSavedAddress();
      if (!mounted || saved == null) return;
      _fullName.text = saved['full_name'] as String? ?? _fullName.text;
      _phone.text = saved['phone'] as String? ?? _phone.text;
      _addressLine1.text = saved['address_line1'] as String? ?? '';
      _addressLine2.text = saved['address_line2'] as String? ?? '';
      _municipality = saved['city'] as String?;
      _barangay = saved['barangay'] as String?;
      _postalCode.text = saved['postal_code'] as String? ?? '';
      _deliveryNote.text = saved['delivery_note'] as String? ?? '';
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _addressLoadError =
            'Saved address could not be loaded. You can still enter it below. ${error.message}');
      }
    } on StateError catch (error) {
      if (mounted) setState(() => _addressLoadError = error.message);
    } finally {
      if (mounted) setState(() => _loadingSavedAddress = false);
    }
  }

  Future<void> _loadLocations() async {
    try {
      final locations = await BoholAddressRepository.loadLocations();
      if (mounted) {
        setState(() {
          _locations = locations;
          if (!_locations.containsKey(_municipality)) {
            _municipality = null;
            _barangay = null;
          } else if (!_locations[_municipality]!.contains(_barangay)) {
            _barangay = null;
          }
        });
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() => _locationsError =
            'Bohol municipality and barangay list could not be loaded: ${error.message}');
      }
    } on FlutterError catch (error) {
      if (mounted) {
        setState(() => _locationsError =
            'Bohol municipality and barangay list could not be loaded: ${error.message}');
      }
    } finally {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  void _continueToPayment() {
    if (widget.lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          total: widget.subtotal + widget.shipping,
          lineItems: widget.lineItems,
          consumeCartItems: widget.removePurchasedItemsFromCart,
          delivery: DeliveryDetails(
            fullName: _fullName.text.trim(),
            phone: _phone.text.trim(),
            addressLine1: _addressLine1.text.trim(),
            addressLine2: _addressLine2.text.trim().isEmpty
                ? null
                : _addressLine2.text.trim(),
            municipality: _municipality!,
            barangay: _barangay!,
            city: _municipality!,
            province: 'Bohol',
            postalCode: _postalCode.text.trim(),
            deliveryNote: _deliveryNote.text.trim().isEmpty
                ? null
                : _deliveryNote.text.trim(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const _CheckoutProgress(),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Add your delivery details. We’ll save them securely with your order.',
                style: TextStyle(
                  color: PawcheColors.muted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const SectionTitle('Delivery address'),
            if (_loadingSavedAddress)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Loading saved delivery details…',
                  style: TextStyle(color: PawcheColors.muted, fontSize: 12),
                ),
              ),
            if (_addressLoadError != null) ...[
              _Notice(
                icon: Icons.info_outline_rounded,
                message: _addressLoadError!,
              ),
              const SizedBox(height: 12),
            ],
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _field(
                    controller: _fullName,
                    label: 'Recipient name',
                    icon: Icons.person_outline_rounded,
                    validator: _required,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _phone,
                    label: 'Mobile number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      final required = _required(value);
                      if (required != null) return required;
                      return value!
                                  .trim()
                                  .replaceAll(RegExp(r'\D'), '')
                                  .length <
                              7
                          ? 'Enter a valid mobile number.'
                          : null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _addressLine1,
                    label: 'House / unit / street',
                    icon: Icons.location_on_outlined,
                    validator: _required,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _addressLine2,
                    label: 'Building or subdivision (optional)',
                    icon: Icons.apartment_outlined,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  if (_locationsError != null) ...[
                    _Notice(
                      icon: Icons.error_outline_rounded,
                      message: _locationsError!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_loadingLocations)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Loading Bohol locations…',
                          style: TextStyle(
                            color: PawcheColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  _locationDropdown(
                    key: ValueKey('municipality-${_municipality ?? ''}'),
                    value: _municipality,
                    label: 'Municipality or city',
                    icon: Icons.location_city_outlined,
                    hint: _loadingLocations
                        ? 'Loading Bohol locations…'
                        : 'Choose your municipality',
                    options: _locations.keys.toList(),
                    validator: (value) => value == null
                        ? 'Choose your municipality or city.'
                        : null,
                    onChanged: (value) => setState(() {
                      _municipality = value;
                      _barangay = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  _locationDropdown(
                    key: ValueKey(
                      'barangay-${_municipality ?? ''}-${_barangay ?? ''}',
                    ),
                    value: _barangay,
                    label: 'Barangay',
                    icon: Icons.holiday_village_outlined,
                    hint: _municipality == null
                        ? 'Choose a municipality first'
                        : 'Choose your barangay',
                    options: _municipality == null
                        ? const []
                        : _locations[_municipality] ?? const [],
                    validator: (value) =>
                        value == null ? 'Choose your barangay.' : null,
                    onChanged: _municipality == null
                        ? null
                        : (value) => setState(() => _barangay = value),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Delivery area: Bohol, Philippines',
                      style: TextStyle(
                        color: PawcheColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _postalCode,
                    label: 'Postal code',
                    icon: Icons.markunread_mailbox_outlined,
                    keyboardType: TextInputType.number,
                    validator: _required,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _deliveryNote,
                    label: 'Delivery instructions (optional)',
                    icon: Icons.notes_rounded,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionTitle('Order summary'),
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final item in widget.lineItems) ...[
                      _SummaryRow(
                        '${item.name} × ${item.quantity}',
                        formatPeso(item.unitPrice * item.quantity),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _SummaryRow(
                      widget.lineItems.isEmpty
                          ? 'Items (${widget.itemCount})'
                          : 'Estimated subtotal',
                      formatPeso(widget.subtotal),
                    ),
                    const SizedBox(height: 10),
                    const _SummaryRow('Delivery', 'Free'),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(),
                    ),
                    _SummaryRow(
                      'Estimated total',
                      formatPeso(widget.subtotal + widget.shipping),
                      total: true,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Final prices and available stock are checked securely when you place the order.',
                      style: TextStyle(
                        color: PawcheColors.muted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            PinkButton(
              label: 'Continue to Payment',
              onPressed: _continueToPayment,
            ),
          ],
        ),
      );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputAction? textInputAction,
    int maxLines = 1,
  }) =>
      TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        textInputAction: textInputAction,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.white,
        ),
      );

  Widget _locationDropdown({
    required Key key,
    required String? value,
    required String label,
    required IconData icon,
    required String hint,
    required List<String> options,
    required String? Function(String?) validator,
    required ValueChanged<String?>? onChanged,
  }) =>
      DropdownButtonFormField<String>(
        key: key,
        initialValue: options.contains(value) ? value : null,
        validator: validator,
        onChanged: onChanged,
        isExpanded: true,
        menuMaxHeight: 360,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.white,
        ),
        hint: Text(hint, overflow: TextOverflow.ellipsis),
        items: [
          for (final option in options)
            DropdownMenuItem(
              value: option,
              child: Text(option, overflow: TextOverflow.ellipsis),
            ),
        ],
      );
}

class _CheckoutProgress extends StatelessWidget {
  const _CheckoutProgress();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          _ProgressStep(number: '1', label: 'Shipping', active: true),
          Expanded(child: Divider()),
          _ProgressStep(number: '2', label: 'Payment'),
          Expanded(child: Divider()),
          _ProgressStep(number: '3', label: 'Review'),
        ],
      );
}

class _ProgressStep extends StatelessWidget {
  final String number;
  final String label;
  final bool active;

  const _ProgressStep({
    required this.number,
    required this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: active ? PawcheColors.pink : PawcheColors.blush,
            child: Text(
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

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool total;

  const _SummaryRow(this.label, this.value, {this.total = false});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: total ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: total ? PawcheColors.darkPink : PawcheColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: total ? 18 : 14,
            ),
          ),
        ],
      );
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String message;

  const _Notice({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PawcheColors.blush,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: PawcheColors.darkPink, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: PawcheColors.navy,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
}
