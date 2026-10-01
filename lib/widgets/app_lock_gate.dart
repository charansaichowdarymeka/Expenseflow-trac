import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../db/database_helper.dart';
import '../providers/theme_provider.dart';
import '../services/pin_lock.dart';
import 'app_text.dart';
import 'pin_pad.dart';
import 'package:provider/provider.dart';

class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool? _lockRequired;
  String _method = 'pin';
  bool _unlocked = false;
  String _input = '';
  bool _error = false;
  bool _biometricBusy = false;
  AppLifecycleState _lastState = AppLifecycleState.resumed;

  final TextEditingController _passcodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passcodeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    var settled = false;
    final timeout = Timer(const Duration(seconds: 5), () {
      if (settled) return;
      settled = true;
      debugPrint('AppLockGate: failed to read Security Lock state, failing open (timed out)');
      if (mounted) {
        setState(() {
          _lockRequired = false;
          _unlocked = true;
        });
      }
    });

    try {
      await AppDatabase.instance.init();
      final enabled = await AppDatabase.instance.getPinEnabled();
      final method = await AppDatabase.instance.getLockMethod();
      if (settled) return;
      settled = true;
      timeout.cancel();
      if (mounted) {
        setState(() {
          _lockRequired = enabled;
          _method = method;
          _unlocked = !enabled;
        });
      }
      if (enabled && method == 'biometric') _tryBiometric();
    } catch (e) {
      if (settled) return;
      settled = true;
      timeout.cancel();
      debugPrint('AppLockGate: failed to read Security Lock state, failing open: $e');
      if (mounted) {
        setState(() {
          _lockRequired = false;
          _unlocked = true;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_lastState == AppLifecycleState.resumed &&
        (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) &&
        (_lockRequired ?? false)) {
      setState(() {
        _unlocked = false;
        _input = '';
        _error = false;
        _passcodeController.clear();
      });
    } else if (_lastState != AppLifecycleState.resumed &&
        state == AppLifecycleState.resumed &&
        (_lockRequired ?? false) &&
        !_unlocked &&
        _method == 'biometric') {
      _tryBiometric();
    }
    _lastState = state;
  }

  Future<void> _tryBiometric() async {
    if (_biometricBusy) return;
    setState(() => _biometricBusy = true);
    final ok = await authenticateWithBiometrics('Unlock ExpenseTracker');
    if (!mounted) return;
    setState(() {
      _biometricBusy = false;
      if (ok) {
        _unlocked = true;
        _error = false;
      } else {
        _error = true;
      }
    });
  }

  void _onPinChange(String value) {
    setState(() => _input = value);
    if (value.length != kPinLength) return;
    verifyPin(value).then((ok) {
      if (!mounted) return;
      if (ok) {
        setState(() {
          _unlocked = true;
          _error = false;
        });
      } else {
        setState(() {
          _error = true;
          _input = '';
        });
      }
    });
  }

  Future<void> _submitPasscode() async {
    final ok = await verifyPasscode(_passcodeController.text);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _unlocked = true;
        _error = false;
      });
    } else {
      setState(() => _error = true);
      _passcodeController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;

    if (_lockRequired == null) {
      return Container(color: colors.background);
    }

    if (_unlocked) {
      return widget.child;
    }

    return Container(
      color: colors.background,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: _method == 'biometric'
          ? _biometricPrompt(colors)
          : _method == 'passcode'
              ? _passcodePrompt(colors)
              : _pinPrompt(colors),
    );
  }

  Widget _pinPrompt(AppColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppText.heading('Enter PIN', style: TextStyle(color: colors.text)),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          child: AppText.caption(
            _error ? 'Incorrect PIN, try again.' : 'Enter your PIN to unlock ExpenseTracker.',
            style: TextStyle(color: _error ? colors.expense : colors.secondary),
          ),
        ),
        PinPad(length: kPinLength, value: _input, onChange: _onPinChange, colors: colors),
      ],
    );
  }

  Widget _passcodePrompt(AppColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText.heading('Enter passcode', style: TextStyle(color: colors.text)),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          child: AppText.caption(
            _error ? 'Incorrect passcode, try again.' : 'Enter your passcode to unlock ExpenseTracker.',
            style: TextStyle(color: _error ? colors.expense : colors.secondary),
          ),
        ),
        TextField(
          controller: _passcodeController,
          obscureText: true,
          autofocus: true,
          maxLength: kPasscodeMaxLength,
          style: TextStyle(color: colors.text),
          onSubmitted: (_) => _submitPasscode(),
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.card,
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ElevatedButton(
            onPressed: _submitPasscode,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Unlock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _biometricPrompt(AppColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.fingerprint, size: 56, color: colors.primary),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: AppText.heading('Unlock ExpenseTracker', style: TextStyle(color: colors.text)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          child: AppText.caption(
            _error ? "Couldn't verify. Try again." : 'Confirm with fingerprint or Face ID.',
            style: TextStyle(color: _error ? colors.expense : colors.secondary),
          ),
        ),
        if (_biometricBusy)
          CircularProgressIndicator(color: colors.primary)
        else
          ElevatedButton(
            onPressed: _tryBiometric,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Unlock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}
