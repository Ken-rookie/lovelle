class AppConfig {
  static const supabaseUrl = 'https://qafeksxxmdqnikzeorba.supabase.co';
  static const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFhZmVrc3h4bWRxbmlremVvcmJhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI3ODI3MzAsImV4cCI6MjEwODM1ODczMH0.fvuNN-3okQURCISxB-jfiI60g8Z78eJxHRYwKLmTWPs';
  static const debug = false;

  static bool get hasSupabaseConfig =>
      supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty;
}
