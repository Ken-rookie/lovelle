import 'package:flutter/material.dart';

import '../config/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/common.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool startInSignUp;

  const LoginScreen({super.key, this.startInSignUp = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  late bool _isSignUp = widget.startInSignUp;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _busy = false;
  bool _showSetupNotice = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _changeMode(bool signUp) {
    if (_busy || _isSignUp == signUp) return;
    _formKey.currentState?.reset();
    setState(() {
      _isSignUp = signUp;
      _showSetupNotice = false;
      _password.clear();
      _confirmPassword.clear();
      _obscurePassword = true;
      _obscureConfirmation = true;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!SupabaseService.isConfigured) {
      setState(() => _showSetupNotice = true);
      return;
    }

    setState(() {
      _busy = true;
      _showSetupNotice = false;
    });
    try {
      if (_isSignUp) {
        await SupabaseService.signUp(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        );
        if (!mounted) return;
        setState(() {
          _isSignUp = false;
          _password.clear();
          _confirmPassword.clear();
          _showSetupNotice = false;
        });
        showMessage(
          context,
          'Account created. Check your email for a confirmation link, then sign in.',
        );
      } else {
        await SupabaseService.signIn(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (mounted) _openAuthenticatedApp();
      }
    } catch (error) {
      if (mounted) showMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openAuthenticatedApp() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AppShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        _isSignUp ? 'Create your Pawché account' : 'Sign in to Pawché';
    final subtitle = _isSignUp
        ? 'Add your details to get started with Pawché.'
        : 'Welcome back, pet parent. Sign in to manage your orders and pet essentials.';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: PawcheLogo(size: 38)),
                  const SizedBox(height: 24),
                  _AuthModeSwitcher(
                    isSignUp: _isSignUp,
                    enabled: !_busy,
                    onChanged: _changeMode,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: const TextStyle(
                      color: PawcheColors.navy,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: PawcheColors.muted,
                      height: 1.4,
                    ),
                  ),
                  if (_isSignUp) ...[
                    const SizedBox(height: 16),
                    const _SignUpIntro(),
                  ],
                  if (_showSetupNotice) ...[
                    const SizedBox(height: 16),
                    _SetupNotice(
                      message: _isSignUp
                          ? 'Supabase is not configured yet. Add your project URL and publishable key in lib/config/app_config.dart to create an account.'
                          : 'Supabase is not configured yet. Add your project URL and publishable key in lib/config/app_config.dart to sign in.',
                    ),
                  ],
                  const SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isSignUp) ...[
                          _fieldLabel('YOUR DETAILS'),
                          const SizedBox(height: 9),
                          TextFormField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon:
                                  Icon(Icons.person_outline_rounded),
                            ),
                            validator: (value) =>
                                _isSignUp &&
                                    (value == null || value.trim().isEmpty)
                                ? 'Enter your full name.'
                                : null,
                          ),
                          const SizedBox(height: 13),
                        ],
                        if (!_isSignUp) _fieldLabel('SIGN IN DETAILS'),
                        if (!_isSignUp) const SizedBox(height: 9),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) return 'Enter your email address.';
                            if (!email.contains('@') || !email.contains('.')) {
                              return 'Enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        if (_isSignUp) ...[
                          const SizedBox(height: 13),
                          TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.telephoneNumber,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Phone number (optional)',
                              helperText:
                                  'Useful for delivery updates about your order.',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                        ],
                        const SizedBox(height: 13),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscurePassword,
                          textInputAction: _isSignUp
                              ? TextInputAction.next
                              : TextInputAction.done,
                          autofillHints: [
                            _isSignUp
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          onFieldSubmitted: (_) {
                            if (!_isSignUp) _submit();
                          },
                          decoration: InputDecoration(
                            labelText:
                                _isSignUp ? 'Create a password' : 'Password',
                            helperText:
                                _isSignUp ? 'Use at least 6 characters.' : null,
                            prefixIcon:
                                const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter your password.';
                            }
                            if (_isSignUp && value.length < 6) {
                              return 'Use at least 6 characters.';
                            }
                            return null;
                          },
                        ),
                        if (_isSignUp) ...[
                          const SizedBox(height: 13),
                          TextFormField(
                            controller: _confirmPassword,
                            obscureText: _obscureConfirmation,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [
                              AutofillHints.newPassword,
                            ],
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Confirm password',
                              prefixIcon:
                                  const Icon(Icons.verified_user_outlined),
                              suffixIcon: IconButton(
                                tooltip: _obscureConfirmation
                                    ? 'Show confirmation password'
                                    : 'Hide confirmation password',
                                onPressed: () => setState(
                                  () => _obscureConfirmation =
                                      !_obscureConfirmation,
                                ),
                                icon: Icon(
                                  _obscureConfirmation
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Confirm your password.';
                              }
                              if (value != _password.text) {
                                return 'Passwords do not match.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!_isSignUp) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                ),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    const _AccountPrivacyNote(),
                  ],
                  const SizedBox(height: 6),
                  PinkButton(
                    label: _busy
                        ? _isSignUp
                            ? 'Creating account…'
                            : 'Signing in…'
                        : _isSignUp
                            ? 'Create my account'
                            : 'Sign in to my account',
                    onPressed: _busy ? null : _submit,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _changeMode(!_isSignUp),
                    child: Text(
                      _isSignUp
                          ? 'Already have an account?  Sign in'
                          : 'New to Pawché?  Create an account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) => Text(
        label,
        style: const TextStyle(
          color: PawcheColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
        ),
      );
}

class _AuthModeSwitcher extends StatelessWidget {
  final bool isSignUp;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _AuthModeSwitcher({
    required this.isSignUp,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: PawcheColors.blush,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _AuthModeButton(
              label: 'Sign in',
              selected: !isSignUp,
              enabled: enabled,
              onTap: () => onChanged(false),
            ),
            _AuthModeButton(
              label: 'Create account',
              selected: isSignUp,
              enabled: enabled,
              onTap: () => onChanged(true),
            ),
          ],
        ),
      );
}

class _AuthModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _AuthModeButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: TextButton(
            onPressed: enabled ? onTap : null,
            style: TextButton.styleFrom(
              backgroundColor: selected ? Colors.white : Colors.transparent,
              foregroundColor:
                  selected ? PawcheColors.darkPink : PawcheColors.muted,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      );
}

class _SignUpIntro extends StatelessWidget {
  const _SignUpIntro();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PawcheColors.blush,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.pets_rounded, color: PawcheColors.darkPink),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A little home for your pet’s essentials',
                    style: TextStyle(
                      color: PawcheColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Create an account to keep your orders and delivery details together.',
                    style: TextStyle(
                      color: PawcheColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _AccountPrivacyNote extends StatelessWidget {
  const _AccountPrivacyNote();

  @override
  Widget build(BuildContext context) => const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 17,
            color: PawcheColors.muted,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your password is kept private. We only use your contact details to support your account and deliveries.',
              style: TextStyle(
                color: PawcheColors.muted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
}

class _SetupNotice extends StatelessWidget {
  final String message;

  const _SetupNotice({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PawcheColors.blush,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PawcheColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: PawcheColors.darkPink,
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: PawcheColors.navy,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
}
