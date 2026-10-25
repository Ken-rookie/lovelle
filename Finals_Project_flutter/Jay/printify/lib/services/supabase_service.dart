import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/print_order.dart';

class SupabaseService {
  SupabaseClient? get _client =>
      AppConfig.hasSupabaseConfig ? Supabase.instance.client : null;

  bool get configured => _client != null;

  bool get authenticated => _client?.auth.currentSession != null;

  String? get currentUserEmail => _client?.auth.currentUser?.email;

  Future<void> signIn(String email, String password) async {
    final client = _client;
    if (client == null) {
      throw Exception(
        'Add your Supabase project URL and publishable key in '
        'lib/config/app_config.dart to log in.',
      );
    }
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception(
        'Add your Supabase project URL and publishable key in '
        'lib/config/app_config.dart to create an account.',
      );
    }
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': name.trim(), 'phone': phone.trim()},
    );
    return response.session != null;
  }

  Future<void> resetPassword(String email) async {
    final client = _client;
    if (client == null) {
      throw Exception(
        'Add your Supabase URL and anon key to run password reset.',
      );
    }
    await client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> signOut() async {
    final client = _client;
    if (client != null) await client.auth.signOut();
  }

  Future<Map<String, dynamic>> createOrder(PrintOrderDraft draft) async {
    final client = _client;
    if (client == null) {
      throw Exception(
        'Supabase is not configured. Add the project URL and publishable key '
        'in lib/config/app_config.dart.',
      );
    }
    final result = await client.functions.invoke(
      'submit-print-order',
      body: draft.toJson(),
    );
    if (result.status < 200 || result.status >= 300) {
      throw Exception('Could not create order: ${result.data}');
    }
    if (result.data is Map<String, dynamic>) {
      return result.data as Map<String, dynamic>;
    }
    throw Exception('Unexpected response from submit-print-order.');
  }

  Future<Map<String, dynamic>> createQrPhPayment({
    required String orderId,
    required double amount,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is not configured.');
    }
    final result = await client.functions.invoke(
      'create-qrph-payment',
      body: {'order_id': orderId, 'amount': amount, 'currency': 'PHP'},
    );
    if (result.status < 200 || result.status >= 300) {
      throw Exception('Could not create QRPh payment: ${result.data}');
    }
    if (result.data is Map<String, dynamic>) {
      return result.data as Map<String, dynamic>;
    }
    throw Exception('Unexpected QRPh response.');
  }

  Future<String> getOrderPaymentStatus(String orderId) async {
    final client = _client;
    if (client == null || client.auth.currentUser == null) {
      throw Exception('Sign in to check payment status.');
    }
    final result = await client.functions.invoke(
      'check-qrph-payment',
      body: {'order_id': orderId},
    );
    if (result.status < 200 || result.status >= 300) {
      throw Exception('Could not refresh payment status: ${result.data}');
    }
    final status = (result.data as Map<String, dynamic>?)?['payment_status'];
    if (status is! String) {
      throw Exception('The server returned an invalid payment status.');
    }
    return status;
  }

  Future<void> selectWalkInPayment(String orderId) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is not configured.');
    }
    final result = await client.functions.invoke(
      'select-walkin-payment',
      body: {'order_id': orderId},
    );
    if (result.status < 200 || result.status >= 300) {
      throw Exception('Could not select walk-in payment: ${result.data}');
    }
  }

  Future<List<Map<String, dynamic>>> getMyOrders() async {
    final client = _client;
    if (client == null || client.auth.currentUser == null) return [];
    final rows = await client
        .from('print_orders')
        .select(
          '*, print_order_files(file_name, file_size_bytes, file_extension, page_count)',
        )
        .eq('user_id', client.auth.currentUser!.id)
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Stream<List<Map<String, dynamic>>> getMyNotifications() {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      throw StateError('Sign in to view notifications.');
    }
    return client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
  }
}
