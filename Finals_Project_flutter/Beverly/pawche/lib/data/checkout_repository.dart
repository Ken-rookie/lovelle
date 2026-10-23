import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_service.dart';
import '../models/checkout.dart';

class CheckoutRepository {
  static Future<List<OrderHistoryEntry>> loadOrderHistory() async {
    final client = _requireClient();
    if (client.auth.currentUser == null) {
      throw StateError('Sign in to view your order history.');
    }
    final rows = await client
        .from('orders')
        .select(
          'id, reference_number, status, payment_status, payment_method, subtotal, delivery_fee, total_amount, shipping_address, created_at',
        )
        .order('created_at', ascending: false)
        .limit(50);
    return _historyEntries(List<Map<String, dynamic>>.from(rows));
  }

  static Future<List<OrderHistoryItem>> loadOrderItems(String orderId) async {
    final client = _requireClient();
    if (client.auth.currentUser == null) {
      throw StateError('Sign in to view your order details.');
    }
    final rows = await client
        .from('order_items')
        .select('product_slug, product_name, unit_price, quantity')
        .eq('order_id', orderId)
        .order('product_name');
    return _itemsWithImages(List<Map<String, dynamic>>.from(rows));
  }

  static Future<List<OrderHistoryEntry>> _historyEntries(
    List<Map<String, dynamic>> orders,
  ) async {
    if (orders.isEmpty) return [];
    final client = _requireClient();
    final orderIds = orders.map((row) => row['id'] as String).toList();
    final itemRows = await client
        .from('order_items')
        .select(
          'order_id, product_slug, product_name, unit_price, quantity',
        )
        .inFilter('order_id', orderIds)
        .order('product_name');
    final itemsByOrder = <String, List<Map<String, dynamic>>>{};
    for (final row in List<Map<String, dynamic>>.from(itemRows)) {
      final orderId = row['order_id'] as String;
      itemsByOrder.putIfAbsent(orderId, () => []).add(row);
    }

    final allItems = await _itemsWithImages(
      itemsByOrder.values.expand((items) => items).toList(),
    );
    final imagesBySlug = {
      for (final item in allItems) item.productSlug: item.imageUrl,
    };
    return orders.map((row) {
      final order = CheckoutOrder.fromJson(row);
      final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
      if (createdAt == null) {
        throw const FormatException('An order has an invalid creation date.');
      }
      final address = row['shipping_address'];
      if (address is! Map) {
        throw const FormatException('An order has invalid delivery details.');
      }
      final orderItems = (itemsByOrder[order.id] ?? [])
          .map(
            (item) => OrderHistoryItem(
              productSlug: item['product_slug'] as String,
              productName: item['product_name'] as String,
              quantity: item['quantity'] as int,
              unitPrice: (item['unit_price'] as num).round(),
              imageUrl: imagesBySlug[item['product_slug'] as String],
            ),
          )
          .toList();
      return OrderHistoryEntry(
        order: order,
        createdAt: createdAt,
        items: orderItems,
        subtotal: (row['subtotal'] as num).round(),
        deliveryFee: (row['delivery_fee'] as num).round(),
        shippingAddress: Map<String, dynamic>.from(address),
      );
    }).toList();
  }

  static Future<List<OrderHistoryItem>> _itemsWithImages(
    List<Map<String, dynamic>> items,
  ) async {
    if (items.isEmpty) return [];
    final slugs = items.map((item) => item['product_slug'] as String).toSet();
    final products = await _requireClient()
        .from('products')
        .select('slug, image_url')
        .inFilter('slug', slugs.toList());
    final imageBySlug = {
      for (final row in List<Map<String, dynamic>>.from(products))
        row['slug'] as String: row['image_url'] as String?,
    };
    return items
        .map(
          (item) => OrderHistoryItem(
            productSlug: item['product_slug'] as String,
            productName: item['product_name'] as String,
            quantity: item['quantity'] as int,
            unitPrice: (item['unit_price'] as num).round(),
            imageUrl: imageBySlug[item['product_slug'] as String],
          ),
        )
        .toList();
  }

  static Future<Map<String, dynamic>?> loadSavedAddress() async {
    final client = _requireClient();
    if (client.auth.currentUser == null) {
      throw StateError('Sign in before checking out.');
    }
    final row = await client
        .from('customer_addresses')
        .select(
          'full_name, phone, address_line1, address_line2, barangay, city, province, postal_code, delivery_note',
        )
        .maybeSingle();
    return row;
  }

  static Future<CheckoutOrder> createOrder({
    required List<CheckoutLineItem> items,
    required DeliveryDetails delivery,
    required String paymentMethod,
    required String requestId,
  }) async {
    final client = _requireClient();
    if (client.auth.currentUser == null) {
      throw StateError('Sign in before placing an order.');
    }
    if (items.isEmpty) {
      throw StateError('Your cart is empty.');
    }

    final response = await client.functions.invoke(
      'create-checkout',
      body: {
        'request_id': requestId,
        'items': items.map((item) => item.toRequestJson()).toList(),
        'delivery': delivery.toJson(),
        'payment_method': paymentMethod,
      },
    );
    final data = response.data;
    if (data is! Map) {
      throw StateError('The checkout service returned an invalid response.');
    }
    return CheckoutOrder.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<CheckoutOrder> refreshOrder(CheckoutOrder order) async {
    final client = _requireClient();
    final row = await client
        .from('orders')
        .select(
          'id, reference_number, status, payment_status, payment_method, total_amount, paymongo_checkout_url',
        )
        .eq('id', order.id)
        .single();
    return CheckoutOrder.fromJson({
      ...Map<String, dynamic>.from(row),
      'checkout_url': row['paymongo_checkout_url'],
    });
  }

  static Future<CheckoutOrder> refreshQrphPayment(CheckoutOrder order) async {
    final client = _requireClient();
    final response = await client.functions.invoke(
      'check-qrph-payment',
      body: {'order_id': order.id},
    );
    final data = response.data;
    if (data is! Map) {
      throw StateError(
          'The payment status service returned an invalid response.');
    }
    final result = Map<String, dynamic>.from(data);
    return order.copyWith(
      status: result['status'] as String?,
      paymentStatus: result['payment_status'] as String?,
      expiresAt: DateTime.tryParse(result['expires_at'] as String? ?? ''),
    );
  }

  static String newRequestId() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static SupabaseClient _requireClient() {
    final client = SupabaseService.initializedClient;
    if (client == null) {
      throw StateError(
        'Live checkout needs the Supabase project to be configured.',
      );
    }
    return client;
  }
}
