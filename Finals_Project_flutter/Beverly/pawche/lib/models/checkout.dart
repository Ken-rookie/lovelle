class CheckoutLineItem {
  final String productSlug;
  final String name;
  final int quantity;
  final int unitPrice;

  const CheckoutLineItem({
    required this.productSlug,
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  Map<String, Object> toRequestJson() => {
        'slug': productSlug,
        'quantity': quantity,
      };
}

class DeliveryDetails {
  final String fullName;
  final String phone;
  final String addressLine1;
  final String? addressLine2;
  final String municipality;
  final String barangay;
  final String city;
  final String province;
  final String postalCode;
  final String? deliveryNote;

  const DeliveryDetails({
    required this.fullName,
    required this.phone,
    required this.addressLine1,
    this.addressLine2,
    required this.municipality,
    required this.barangay,
    required this.city,
    required this.province,
    required this.postalCode,
    this.deliveryNote,
  });

  factory DeliveryDetails.fromJson(Map<String, dynamic> json) =>
      DeliveryDetails(
        fullName: json['full_name'] as String,
        phone: json['phone'] as String,
        addressLine1: json['address_line1'] as String,
        addressLine2: json['address_line2'] as String?,
        municipality: json['municipality'] as String,
        barangay: json['barangay'] as String,
        city: json['city'] as String,
        province: json['province'] as String,
        postalCode: json['postal_code'] as String,
        deliveryNote: json['delivery_note'] as String?,
      );

  Map<String, String?> toJson() => {
        'full_name': fullName,
        'phone': phone,
        'address_line1': addressLine1,
        'address_line2': addressLine2,
        'municipality': municipality,
        'barangay': barangay,
        'city': city,
        'province': province,
        'postal_code': postalCode,
        'delivery_note': deliveryNote,
      };
}

class CheckoutOrder {
  final String id;
  final String referenceNumber;
  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final int totalAmount;
  final String? checkoutUrl;
  final String? qrImageUrl;
  final DateTime? expiresAt;

  const CheckoutOrder({
    required this.id,
    required this.referenceNumber,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.totalAmount,
    this.checkoutUrl,
    this.qrImageUrl,
    this.expiresAt,
  });

  factory CheckoutOrder.fromJson(Map<String, dynamic> json) => CheckoutOrder(
        id: json['order_id'] as String? ?? json['id'] as String,
        referenceNumber: json['reference_number'] as String? ?? 'Pawché order',
        status: json['status'] as String? ?? 'awaiting_payment',
        paymentStatus: json['payment_status'] as String? ?? 'awaiting_payment',
        paymentMethod: json['payment_method'] as String,
        totalAmount: ((json['total_amount'] ?? json['total']) as num).round(),
        checkoutUrl: json['checkout_url'] as String?,
        qrImageUrl: json['qr_image_url'] as String?,
        expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
      );

  CheckoutOrder copyWith({
    String? status,
    String? paymentStatus,
    String? checkoutUrl,
    String? qrImageUrl,
    DateTime? expiresAt,
  }) =>
      CheckoutOrder(
        id: id,
        referenceNumber: referenceNumber,
        status: status ?? this.status,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        paymentMethod: paymentMethod,
        totalAmount: totalAmount,
        checkoutUrl: checkoutUrl ?? this.checkoutUrl,
        qrImageUrl: qrImageUrl ?? this.qrImageUrl,
        expiresAt: expiresAt ?? this.expiresAt,
      );
}

class OrderHistoryItem {
  final String productSlug;
  final String productName;
  final int quantity;
  final int unitPrice;
  final String? imageUrl;

  const OrderHistoryItem({
    required this.productSlug,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.imageUrl,
  });
}

class OrderHistoryEntry {
  final CheckoutOrder order;
  final DateTime createdAt;
  final List<OrderHistoryItem> items;
  final int subtotal;
  final int deliveryFee;
  final Map<String, dynamic> shippingAddress;

  const OrderHistoryEntry({
    required this.order,
    required this.createdAt,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.shippingAddress,
  });
}
