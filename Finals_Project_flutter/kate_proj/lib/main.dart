import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'services/supabase_service.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.isConfigured) {
    await SupabaseService.initialize();
  }
  runApp(const LovelleApp());
}

class LovelleApp extends StatelessWidget {
  const LovelleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lovelle',
      debugShowCheckedModeBanner: false,
      theme: LovelleTheme.light,
      home: const SplashScreen(),
    );
  }
}
