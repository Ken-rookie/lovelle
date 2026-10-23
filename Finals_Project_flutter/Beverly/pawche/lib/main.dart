import 'dart:async';

import 'package:flutter/material.dart';
import 'config/supabase_service.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PawcheApp());
  unawaited(_initializeServices());
}

Future<void> _initializeServices() async {
  try {
    await SupabaseService.initialize();
  } catch (error, stackTrace) {
    debugPrint('Pawche: Supabase initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
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
