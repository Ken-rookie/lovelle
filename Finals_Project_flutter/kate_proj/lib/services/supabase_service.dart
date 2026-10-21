import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../models/product.dart';

class SupabaseService {
  static bool _initialized = false;

  static bool get ready => AppConfig.isConfigured && _initialized;
  static SupabaseClient get client => Supabase.instance.client;
  static String? get userId => ready ? client.auth.currentUser?.id : null;

  static Future<void> initialize() async {
    if (!AppConfig.isConfigured || _initialized) return;

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );
    _initialized = true;
  }

  static Future<void> signUp(
      {required String name,
      required String email,
      required String password}) async {
    final res = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': name.trim()});
    if (res.user != null && res.session != null) {
      await client.from('profiles').upsert({
        'id': res.user!.id,
        'full_name': name.trim(),
        'email': email.trim()
      });
    }
  }

  static Future<void> signIn(String email, String password) async {
    await client.auth
        .signInWithPassword(email: email.trim(), password: password);
  }

  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email.trim());
  }

  static Future<void> signOut() async => client.auth.signOut();

  static Future<Map<String, dynamic>?> getProfile() async {
    final id = userId;
    if (id == null) return null;
    final rows =
        await client.from('profiles').select().eq('id', id).maybeSingle();
    return rows;
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    final rows = await client
        .from('categories')
        .select('id,name,image_url')
        .eq('is_active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<List<Product>> getProducts(
      {String? categoryId, String? search, bool featuredOnly = false}) async {
    var query = client
        .from('products')
        .select('*, categories(name)')
        .eq('is_available', true);
    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.eq('category_id', categoryId);
    }
    if (featuredOnly) {
      query = query.eq('is_featured', true);
    }
    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('name', '%${search.trim()}%');
    }
    final rows = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows).map(Product.fromMap).toList();
  }

  static Future<List<Product>> getWishlist() async {
    final rows = await client
        .from('wishlist')
        .select('product_id, products(*, categories(name))')
        .eq('customer_id', userId!);
    return rows
        .map((r) =>
            Product.fromMap(Map<String, dynamic>.from(r['products'] as Map)))
        .toList();
  }

  static Future<bool> isWishlisted(String productId) async {
    final row = await client
        .from('wishlist')
        .select('id')
        .eq('customer_id', userId!)
        .eq('product_id', productId)
        .maybeSingle();
    return row != null;
  }

  static Future<void> toggleWishlist(String productId) async {
    final existing = await client
        .from('wishlist')
        .select('id')
        .eq('customer_id', userId!)
        .eq('product_id', productId)
        .maybeSingle();
    if (existing == null) {
      await client
          .from('wishlist')
          .insert({'customer_id': userId, 'product_id': productId});
    } else {
      await client.from('wishlist').delete().eq('id', existing['id']);
    }
  }

  static Future<int> getCartCount() async {
    final rows =
        await client.from('cart_items').select('id').eq('customer_id', userId!);
    return List<Map<String, dynamic>>.from(rows).length;
  }

  static Future<int> getWishlistCount() async {
    final rows =
        await client.from('wishlist').select('id').eq('customer_id', userId!);
    return List<Map<String, dynamic>>.from(rows).length;
  }

  static Future<List<Map<String, dynamic>>> getCart() async {
    final rows = await client
        .from('cart_items')
        .select('id,quantity,product_id,products(*, categories(name))')
        .eq('customer_id', userId!)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> addToCart(String productId, {int quantity = 1}) async {
    if (quantity < 1) {
      throw ArgumentError.value(quantity, 'quantity', 'Must be positive.');
    }
    final product = await client
        .from('products')
        .select('stock_quantity,is_available')
        .eq('id', productId)
        .single();
    final stock = int.tryParse(product['stock_quantity'].toString()) ?? 0;
    if (product['is_available'] != true || stock < 1) {
      throw StateError('This gift is currently unavailable.');
    }

    final existing = await client
        .from('cart_items')
        .select('id,quantity')
        .eq('customer_id', userId!)
        .eq('product_id', productId)
        .maybeSingle();
    final inCart = (existing?['quantity'] as int?) ?? 0;
    if (inCart + quantity > stock) {
      throw StateError(
          'Only $stock of this gift ${stock == 1 ? 'is' : 'are'} available.');
    }
    if (existing == null) {
      await client.from('cart_items').insert({
        'customer_id': userId,
        'product_id': productId,
        'quantity': quantity
      });
    } else {
      await client
          .from('cart_items')
          .update({'quantity': (existing['quantity'] as int) + quantity}).eq(
              'id', existing['id']);
    }
  }

  static Future<void> setCartQuantity(String id, int quantity) async {
    if (quantity <= 0) {
      await client.from('cart_items').delete().eq('id', id);
    } else {
      final item = await client
          .from('cart_items')
          .select('product_id,products(stock_quantity,is_available)')
          .eq('id', id)
          .maybeSingle();
      if (item == null || item['products'] == null) {
        throw StateError('This cart item is no longer available.');
      }
      final product = Map<String, dynamic>.from(item['products'] as Map);
      final stock = int.tryParse(product['stock_quantity'].toString()) ?? 0;
      if (product['is_available'] != true || quantity > stock) {
        throw StateError(
          stock < 1
              ? 'This gift is currently unavailable.'
              : 'Only $stock of this gift are available.',
        );
      }
      await client
          .from('cart_items')
          .update({'quantity': quantity}).eq('id', id);
    }
  }

  static Future<void> clearCart() async =>
      client.from('cart_items').delete().eq('customer_id', userId!);

  static Future<List<Map<String, dynamic>>> getAddresses() async {
    final rows = await client
        .from('addresses')
        .select()
        .eq('customer_id', userId!)
        .order('is_default', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> saveAddress(Map<String, dynamic> address) async {
    await client.from('addresses').insert({...address, 'customer_id': userId});
  }

  static Future<List<Map<String, dynamic>>> getOrders() async {
    final rows = await client
        .from('orders')
        .select('*, order_items(*)')
        .eq('customer_id', userId!)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<Map<String, dynamic>> placeOrder(
      {required String recipient,
      required String phone,
      required String address,
      required String fulfillment,
      required String paymentMethod,
      required bool wrapping,
      required bool greetingCard,
      required String greetingMessage,
      required Map<String, String> roseTypes}) async {
    if (paymentMethod != 'cash_on_delivery') {
      throw ArgumentError.value(
        paymentMethod,
        'paymentMethod',
        'Only cash-on-delivery orders use this operation.',
      );
    }
    final result = await client.rpc(
      'place_cash_on_delivery_order',
      params: {
        'p_fulfillment': fulfillment,
        'p_recipient': recipient,
        'p_phone': phone,
        'p_address': address,
        'p_wrapping': wrapping,
        'p_greeting_card': greetingCard,
        'p_greeting_message': greetingMessage,
        'p_rose_types': roseTypes,
      },
    );
    if (result is! Map) {
      throw StateError('Order service returned an invalid response.');
    }
    return Map<String, dynamic>.from(result);
  }

  static Future<void> cancelOwnPendingOrder(String orderId) async {
    await client.rpc(
      'cancel_own_pending_order',
      params: {'p_order_id': orderId},
    );
  }

  static Future<void> updateProfile(
      {required String name,
      required String phone,
      required String addressLine,
      required String city}) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to save your profile.');
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw StateError('Your account does not have an email address.');
    }

    await client.from('profiles').upsert({
      'id': user.id,
      'email': email,
      'full_name': name.trim(),
      'phone': phone.trim(),
      'address_line': addressLine.trim().isEmpty ? null : addressLine.trim(),
      'city': city.trim().isEmpty ? null : city.trim(),
    }, onConflict: 'id');
  }

  static Future<List<Map<String, dynamic>>> getReviews() async {
    final rows = await client
        .from('reviews')
        .select('*, products(name,image_url)')
        .eq('customer_id', userId!)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }
}
