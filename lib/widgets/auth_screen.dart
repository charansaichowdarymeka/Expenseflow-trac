import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'app_text.dart';

enum _AuthMode { login, register, forgot }

/// Sign-in / sign-up / forgot-password form for cloud sync.
///
/// Embedded directly in [CloudSyncScreen] rather than gating the whole app —
/// the rest of ExpenseTracker works fully offline without an account.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  _AuthMode _mode = _AuthMode.login;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String _error = '';
  String _info = '';
  bool _busy = false;

  void _resetFields() {
    _error = '';
    _info = '';
  }

  void _switchMode(_AuthMode next) {
    setState(() {
      _resetFields();
      _mode = next;
    });
  }

  Future<void> _handleSubmit() async {
    setState(_resetFields);
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address.');
      return;
    }

    final auth = context.read<AppAuthProvider>();

    if (_mode == _AuthMode.forgot) {
      setState(() => _busy = true);
      try {
        await auth.resetPassword(email);
        setState(() => _info = 'Password reset email sent — check your inbox.');
      } catch (e) {
        setState(() => _error = authErrorMessage(e));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    if (_mode == _AuthMode.register && password != _confirmController.text) {
      setState(() => _error = "Passwords don't match.");
      return;
    }
    if (_mode == _AuthMode.register && password.length < 6) {
      setState(() => _error = 'Password should be at least 6 characters.');
      return;
    }

    setState(() => _busy = true);
    try {
      if (_mode == _AuthMode.login) {
        await auth.signIn(email, password);
      } else {
        await auth.signUp(email, password);
      }
    } catch (e) {
      setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;
    final title = _mode == _AuthMode.login
        ? 'Welcome back'
        : _mode == _AuthMode.register
            ? 'Create your account'
            : 'Reset your password';
    final subtitle = _mode == _AuthMode.login
        ? 'Sign in to sync your data across devices.'
        : _mode == _AuthMode.register
            ? 'Create an account to back up and sync your data.'
            : "Enter the email on your account and we'll send you a reset link.";
    final submitLabel = _mode == _AuthMode.login ? 'Sign in' : _mode == _AuthMode.register ? 'Create account' : 'Send reset email';

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Image.asset('assets/icon/brand_logo.png', width: 148, height: 148),
                ),
                AppText.heading(title, style: TextStyle(color: colors.text), textAlign: TextAlign.center),
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 24),
                  child: AppText.caption(subtitle, style: TextStyle(color: colors.secondary), textAlign: TextAlign.center),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppText.caption('Email', style: TextStyle(color: colors.secondary)),
                ),
                const SizedBox(height: 6),
                _AuthField(controller: _emailController, hint: 'you@example.com', colors: colors, keyboardType: TextInputType.emailAddress),
                if (_mode != _AuthMode.forgot) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppText.caption('Password', style: TextStyle(color: colors.secondary)),
                  ),
                  const SizedBox(height: 6),
                  _AuthField(controller: _passwordController, hint: '••••••••', colors: colors, obscure: true),
                ],
                if (_mode == _AuthMode.register) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppText.caption('Confirm password', style: TextStyle(color: colors.secondary)),
                  ),
                  const SizedBox(height: 6),
                  _AuthField(controller: _confirmController, hint: '••••••••', colors: colors, obscure: true),
                ],
                if (_mode == _AuthMode.login)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextButton(
                        onPressed: () => _switchMode(_AuthMode.forgot),
                        child: Text('Forgot password?', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: AppText.caption(_error, style: TextStyle(color: colors.expense)),
                  ),
                if (_info.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: AppText.caption(_info, style: TextStyle(color: colors.income)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(submitLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                if (_mode == _AuthMode.login)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: TextButton(
                      onPressed: () => _switchMode(_AuthMode.register),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(color: colors.secondary, fontSize: 13),
                          children: [
                            const TextSpan(text: "Don't have an account? "),
                            TextSpan(text: 'Sign up', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_mode == _AuthMode.register)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: TextButton(
                      onPressed: () => _switchMode(_AuthMode.login),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(color: colors.secondary, fontSize: 13),
                          children: [
                            const TextSpan(text: 'Already have an account? '),
                            TextSpan(text: 'Sign in', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_mode == _AuthMode.forgot)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: TextButton(
                      onPressed: () => _switchMode(_AuthMode.login),
                      child: Text('Back to sign in', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final dynamic colors;
  final bool obscure;
  final TextInputType? keyboardType;

  const _AuthField({
    required this.controller,
    required this.hint,
    required this.colors,
    this.obscure = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autocorrect: false,
      style: TextStyle(color: colors.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.secondary),
        filled: true,
        fillColor: colors.card,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.primary)),
      ),
    );
  }
}
