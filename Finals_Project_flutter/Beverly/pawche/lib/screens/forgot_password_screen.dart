import 'package:flutter/material.dart';

import '../config/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;
    if (!SupabaseService.isConfigured) {
      showMessage(
        context,
        'Supabase is not configured. Add the project URL and publishable key in lib/config/app_config.dart to reset your password.',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await SupabaseService.resetPassword(_email.text.trim());
      if (mounted) {
        showMessage(
          context,
          'If the account exists, a reset email will be sent.',
        );
      }
    } catch (error) {
      if (mounted) showMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Reset Password')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          children: [
            Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: PawcheColors.blush,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_reset_rounded,
                size: 42,
                color: PawcheColors.darkPink,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Forgot your password?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PawcheColors.navy,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the email linked to your Pawché account and we’ll send you a reset link.',
              textAlign: TextAlign.center,
              style: TextStyle(color: PawcheColors.muted, height: 1.45),
            ),
            const SizedBox(height: 26),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty || !email.contains('@')) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            PinkButton(
              label: _busy ? 'Sending...' : 'Send Reset Link',
              onPressed: _busy ? null : _sendResetLink,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              child: const Text('Back to Login'),
            ),
          ],
        ),
      );
}
