import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';

class SupabaseService {
  static bool get isConfigured => AppConfig.hasSupabase;
  static bool _initialized = false;

  static SupabaseClient? get client =>
      isConfigured ? Supabase.instance.client : null;
  static SupabaseClient? get initializedClient =>
      isConfigured && _initialized ? Supabase.instance.client : null;

  static Future<void> initialize() async {
    if (!isConfigured) {
      debugPrint(
        'Pawche: Supabase is not configured; authentication is unavailable.',
      );
      return;
    }
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
    _initialized = true;
  }

  static Future<void> signUp({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final c = client;
    if (c == null) {
      throw StateError(
        'Supabase is not configured. Add the project URL and publishable key in lib/config/app_config.dart.',
      );
    }
    await c.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name, if (phone != null) 'phone': phone},
    );
  }

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final c = client;
    if (c == null) {
      throw StateError(
        'Supabase is not configured. Add the project URL and publishable key in lib/config/app_config.dart.',
      );
    }
    await c.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> resetPassword(String email) async {
    final c = client;
    if (c == null) {
      throw StateError(
        'Supabase is not configured. Add the project URL and publishable key in lib/config/app_config.dart.',
      );
    }
    await c.auth.resetPasswordForEmail(email);
  }

  static Future<void> signOut() async {
    final c = client;
    if (c != null) {
      await c.auth.signOut();
    }
  }
}
