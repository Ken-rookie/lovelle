import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/primary_button.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final service = SupabaseService();
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  bool signup = false;
  bool forgot = false;
  bool busy = false;
  bool obscure = true;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      if (forgot) {
        await service.resetPassword(email.text);
        message('Password reset email sent if the address is registered.');
      } else if (signup) {
        final signedIn = await service.signUp(
          name: name.text,
          email: email.text,
          phone: phone.text,
          password: password.text,
        );
        if (signedIn) {
          widget.onDone();
        } else {
          setState(() => signup = false);
          message('Account created. Confirm your email, then log in.');
        }
      } else {
        await service.signIn(email.text, password.text);
        widget.onDone();
      }
    } catch (e) {
      message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final title = forgot
        ? 'Reset your password'
        : signup
            ? 'Create account'
            : 'Welcome back!';
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: formKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.print_rounded,
                        size: 62, color: Color(0xFF0866F5)),
                    const SizedBox(height: 8),
                    const Text('Printify',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0866F5))),
                    const SizedBox(height: 28),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 25, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                        forgot
                            ? 'Enter your email and we will send a reset link.'
                            : signup
                                ? 'Join us and start printing.'
                                : 'Log in to continue.',
                        style: const TextStyle(color: Colors.blueGrey)),
                    const SizedBox(height: 24),
                    if (signup) ...[
                      TextFormField(
                          controller: name,
                          decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline)),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Enter your name'
                              : null),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                              labelText: 'Phone number',
                              prefixIcon: Icon(Icons.phone_outlined))),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.mail_outline)),
                        validator: (v) => (v ?? '').contains('@')
                            ? null
                            : 'Enter a valid email'),
                    if (!forgot) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: password,
                        obscureText: obscure,
                        decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                                icon: Icon(obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () =>
                                    setState(() => obscure = !obscure))),
                        validator: (v) => (v ?? '').length < 6
                            ? 'Use at least 6 characters'
                            : null,
                      ),
                    ],
                    if (!signup && !forgot)
                      Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                              onPressed: () => setState(() => forgot = true),
                              child: const Text('Forgot password?'))),
                    const SizedBox(height: 12),
                    PrimaryButton(
                        label: forgot
                            ? 'Send reset link'
                            : signup
                                ? 'Create account'
                                : 'Login',
                        onPressed: submit,
                        loading: busy),
                    const SizedBox(height: 14),
                    TextButton(
                        onPressed: () => setState(() {
                              signup = !signup;
                              forgot = false;
                            }),
                        child: Text(signup
                            ? 'Already have an account? Log in'
                            : 'Don’t have an account? Sign up')),
                    if (forgot)
                      TextButton(
                          onPressed: () => setState(() => forgot = false),
                          child: const Text('Back to login')),
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}
