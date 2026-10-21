/// Paste your Supabase project URL and anon/publishable key here.
/// Supabase Dashboard -> Project Settings -> API.
/// NEVER put a service_role key in a mobile app.
class AppConfig {
  static const String supabaseUrl = 'https://pmzbggxqqirsvpqtiwhd.supabase.co';
  static const String supabasePublishableKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBtemJnZ3hxcWlyc3ZwcXRpd2hkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA4NTcwOTcsImV4cCI6MjEwNjQzMzA5N30.GcdQaRT9njzyIjqZFypdtTCjR35AUazemDUnwksC5w8';

  // Backwards compatibility for older references.
  static const String supabaseAnonKey = supabasePublishableKey;

  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') &&
      !supabaseUrl.contains('YOUR_SUPABASE') &&
      supabasePublishableKey.isNotEmpty &&
      !supabasePublishableKey.contains('YOUR_SUPABASE');

}
