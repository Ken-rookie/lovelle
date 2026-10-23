class AppConfig {
  static const supabaseUrl = 'https://risghsrceyjbjyijbjdr.supabase.co';
  static const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJpc2doc3JjZXlqYmp5aWpiamRyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI1NzU2NjEsImV4cCI6MjEwODE1MTY2MX0.P4CVCFzLW8QIxLvBz0juqMdFcuaTAjwYuy8LO4sSmdk';

  static bool get hasSupabase =>
      supabaseUrl.startsWith('https://') &&
      supabaseUrl.endsWith('.supabase.co') &&
      supabaseAnonKey.trim().isNotEmpty &&
      !supabaseAnonKey.startsWith('PASTE_');
}
