import 'supabase_service.dart';

class PayMongoPaymentSession {
  const PayMongoPaymentSession({
    required this.id,
    required this.qrCodeUrl,
    required this.expiresAt,
    required this.status,
  });

  final String id;
  final String qrCodeUrl;
  final DateTime expiresAt;
  final String status;
}

class PayMongoService {
  static const Duration paymentWindow = Duration(minutes: 5);

  static Future<PayMongoPaymentSession> createQrPhSource({
    required String fulfillment,
    required bool wrapping,
    required bool greetingCard,
  }) async {
    final payload = await _invoke({
      'action': 'create',
      'fulfillment': fulfillment,
      'wrapping': wrapping,
      'greetingCard': greetingCard,
    });
    final expiresAt =
        DateTime.tryParse(payload['expiresAt']?.toString() ?? '') ??
            DateTime.now().add(paymentWindow);

    return PayMongoPaymentSession(
      id: payload['paymentIntentId']?.toString() ?? '',
      qrCodeUrl: payload['qrCodeUrl']?.toString() ?? '',
      expiresAt: expiresAt,
      status: payload['status']?.toString() ?? 'pending',
    );
  }

  static Future<String> checkSourceStatus(String sourceId) async {
    final payload = await _invoke({
      'action': 'status',
      'paymentIntentId': sourceId,
    });
    return payload['status']?.toString() ?? 'pending';
  }

  static Future<Map<String, dynamic>> finalizePaidOrder({
    required String paymentIntentId,
    required String fulfillment,
    required String recipient,
    required String phone,
    required String address,
    required bool wrapping,
    required bool greetingCard,
    required String greetingMessage,
    required Map<String, String> roseTypes,
  }) async {
    final payload = await _invoke({
      'action': 'finalize',
      'paymentIntentId': paymentIntentId,
      'fulfillment': fulfillment,
      'recipient': recipient,
      'phone': phone,
      'address': address,
      'wrapping': wrapping,
      'greetingCard': greetingCard,
      'greetingMessage': greetingMessage,
      'roseTypes': roseTypes,
    });
    if (payload['order'] is! Map) {
      throw StateError('PayMongo function did not return the created order.');
    }
    return Map<String, dynamic>.from(payload['order'] as Map);
  }

  static Future<Map<String, dynamic>> _invoke(
    Map<String, dynamic> body,
  ) async {
    final response = await SupabaseService.client.functions.invoke(
      'paymongo',
      body: body,
    );
    if (response.data is! Map) {
      throw StateError('PayMongo function returned an invalid response.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }
}
