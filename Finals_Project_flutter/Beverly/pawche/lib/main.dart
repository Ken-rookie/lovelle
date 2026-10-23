import 'package:flutter/material.dart';
import 'config/supabase_service.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const PawcheApp());
}

class PawcheApp extends StatelessWidget {
  const PawcheApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'Pawché',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen());
}
