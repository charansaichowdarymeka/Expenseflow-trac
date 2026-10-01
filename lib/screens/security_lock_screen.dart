import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../db/database_helper.dart';
import '../providers/theme_provider.dart';
import '../services/pin_lock.dart';
import '../widgets/app_text.dart';
import '../widgets/pin_pad.dart';

enum _Mode { status, pickMethod, enterNewPin, confirmNewPin, enterNewPasscode, confirmNewPasscode, verifyCurrent }

enum _PendingAction { none, disable, changeMethod }

String _methodLabel(String method) {
  switch (method) {
    case 'passcode':
      return 'Passcode';
    case 'biometric':
      return 'Fingerprint / Face ID';
    default:
      return 'PIN';
  }
}

class SecurityLockScreen extends StatefulWidget {
  const SecurityLockScreen({super.key});

  @override
  State<SecurityLockScreen> createState() => _SecurityLockScreenState();
}

class _SecurityLockScreenState extends State<SecurityLockScreen> {
  bool _lockEnabled = false;
  String _method = 'pin';
  bool _biometricAvailable = false;
  bool _biometricIsFace = false;

  _Mode _mode = _Mode.status;
  _PendingAction _pendingAction = _PendingAction.none;
  String _input = '';
  String _firstValue = '';
  String _error = '';
  bool _verifyingBiometric = false;

  final TextEditingController _passcodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final db = AppDatabase.instance;
      await db.init();
      final enabled = await db.getPinEnabled();
      final method = await db.getLockMethod();
      final biometricAvailable = await isBiometricAvailable();
      final biometricIsFace = biometricAvailable ? await isFaceBiometric() : false;
      if (!mounted) return;
      setState(() {
        _lockEnabled = enabled;
        _method = method;
        _biometricAvailable = biometricAvailable;
        _biometricIsFace = biometricIsFace;
      });
    } catch (e) {
      debugPrint('Failed to load Security Lock status: $e');
    }
  }

  Future<void> _showDialog(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  void _resetToStatus() {
    setState(() {
      _mode = _Mode.status;
      _pendingAction = _PendingAction.none;
      _input = '';
      _firstValue = '';
      _error = '';
      _passcodeController.clear();
    });
  }

  void _startEnable() {
    setState(() {
      _error = '';
      _input = '';
      _firstValue = '';
      _passcodeController.clear();
      _mode = _Mode.pickMethod;
    });
  }

  void _startChangeMethod() {
    setState(() {
      _error = '';
      _input = '';
      _pendingAction = _PendingAction.changeMethod;
      _mode = _Mode.verifyCurrent;
    });
    if (_method == 'biometric') _runBiometricVerify();
  }

  void _startDisable() {
    setState(() {
      _error = '';
      _input = '';
      _pendingAction = _PendingAction.disable;
      _mode = _Mode.verifyCurrent;
    });
    if (_method == 'biometric') _runBiometricVerify();
  }

  Future<void> _runBiometricVerify() async {
    setState(() => _verifyingBiometric = true);
    final ok = await authenticateWithBiometrics('Confirm to continue');
    if (!mounted) return;
    setState(() => _verifyingBiometric = false);
    if (ok) {
      _onVerified();
    } else {
      setState(() => _error = "Couldn't verify. Try again.");
    }
  }

  Future<void> _onVerified() async {
    final pending = _pendingAction;
    if (pending == _PendingAction.disable) {
      await clearPin();
      await clearPasscode();
      await AppDatabase.instance.setLockMethod('pin');
      await AppDatabase.instance.setPinEnabled(false);
      if (!mounted) return;
      setState(() {
        _lockEnabled = false;
        _method = 'pin';
      });
      _resetToStatus();
      await _showDialog('Security Lock off', 'Security Lock has been disabled.');
    } else if (pending == _PendingAction.changeMethod) {
      setState(() {
        _mode = _Mode.pickMethod;
        _pendingAction = _PendingAction.none;
        _input = '';
        _error = '';
        _passcodeController.clear();
      });
    }
  }

  Future<void> _selectMethod(String method) async {
    if (method == 'biometric') {
      setState(() => _verifyingBiometric = true);
      final ok = await authenticateWithBiometrics('Confirm to enable Security Lock');
      if (!mounted) return;
      setState(() => _verifyingBiometric = false);
      if (!ok) {
        setState(() => _error = "Couldn't verify. Try again.");
        return;
      }
      await clearPin();
      await clearPasscode();
      await AppDatabase.instance.setLockMethod('biometric');
      await AppDatabase.instance.setPinEnabled(true);
      if (!mounted) return;
      setState(() {
        _lockEnabled = true;
        _method = 'biometric';
      });
      _resetToStatus();
      await _showDialog('Security Lock on', 'Fingerprint / Face ID lock is now active.');
      return;
    }

    setState(() {
      _error = '';
      _input = '';
      _firstValue = '';
      _passcodeController.clear();
      _mode = method == 'passcode' ? _Mode.enterNewPasscode : _Mode.enterNewPin;
    });
  }

  Future<void> _handlePinInputChange(String value) async {
    setState(() => _input = value);
    if (value.length != kPinLength) return;

    if (_mode == _Mode.enterNewPin) {
      setState(() {
        _firstValue = value;
        _input = '';
        _mode = _Mode.confirmNewPin;
      });
    } else if (_mode == _Mode.confirmNewPin) {
      if (value == _firstValue) {
        await setPin(value);
        await clearPasscode();
        await AppDatabase.instance.setLockMethod('pin');
        await AppDatabase.instance.setPinEnabled(true);
        if (!mounted) return;
        setState(() {
          _lockEnabled = true;
          _method = 'pin';
        });
        _resetToStatus();
        await _showDialog('Security Lock on', 'Your PIN lock is now active.');
      } else {
        setState(() {
          _error = "PINs didn't match. Try again.";
          _input = '';
          _firstValue = '';
          _mode = _Mode.enterNewPin;
        });
      }
    } else if (_mode == _Mode.verifyCurrent) {
      if (await verifyPin(value)) {
        _onVerified();
      } else {
        setState(() {
          _error = 'Incorrect PIN.';
          _input = '';
        });
      }
    }
  }

  Future<void> _submitPasscode() async {
    final value = _passcodeController.text;
    if (value.length < kPasscodeMinLength) {
      setState(() => _error = 'Passcode must be at least $kPasscodeMinLength characters.');
      return;
    }

    if (_mode == _Mode.enterNewPasscode) {
      setState(() {
        _firstValue = value;
        _error = '';
        _mode = _Mode.confirmNewPasscode;
        _passcodeController.clear();
      });
    } else if (_mode == _Mode.confirmNewPasscode) {
      if (value == _firstValue) {
        await setPasscode(value);
        await clearPin();
        await AppDatabase.instance.setLockMethod('passcode');
        await AppDatabase.instance.setPinEnabled(true);
        if (!mounted) return;
        setState(() {
          _lockEnabled = true;
          _method = 'passcode';
        });
        _resetToStatus();
        await _showDialog('Security Lock on', 'Your passcode lock is now active.');
      } else {
        setState(() {
          _error = "Passcodes didn't match. Try again.";
          _firstValue = '';
          _mode = _Mode.enterNewPasscode;
          _passcodeController.clear();
        });
      }
    } else if (_mode == _Mode.verifyCurrent) {
      if (await verifyPasscode(value)) {
        _passcodeController.clear();
        _onVerified();
      } else {
        setState(() => _error = 'Incorrect passcode.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;

    switch (_mode) {
      case _Mode.status:
        return _statusScreen(colors);
      case _Mode.pickMethod:
        return _pickMethodScreen(colors);
      case _Mode.enterNewPin:
      case _Mode.confirmNewPin:
        return _pinEntryScreen(colors);
      case _Mode.enterNewPasscode:
      case _Mode.confirmNewPasscode:
        return _passcodeEntryScreen(colors);
      case _Mode.verifyCurrent:
        return _verifyCurrentScreen(colors);
    }
  }

  Widget _scaffold(AppColors colors, Widget child) {
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _pinEntryScreen(AppColors colors) {
    const prompts = {_Mode.enterNewPin: 'Choose a PIN', _Mode.confirmNewPin: 'Confirm your PIN'};
    return _scaffold(
      colors,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText.heading(prompts[_mode]!, style: TextStyle(color: colors.text)),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            child: AppText.caption(
              _error.isNotEmpty ? _error : 'Enter a $kPinLength-digit PIN.',
              style: TextStyle(color: _error.isNotEmpty ? colors.expense : colors.secondary),
            ),
          ),
          PinPad(length: kPinLength, value: _input, onChange: _handlePinInputChange, colors: colors),
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: TextButton(
              onPressed: _resetToStatus,
              child: Text('Cancel', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passcodeEntryScreen(AppColors colors) {
    const prompts = {_Mode.enterNewPasscode: 'Choose a passcode', _Mode.confirmNewPasscode: 'Confirm your passcode'};
    return _scaffold(
      colors,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText.heading(prompts[_mode]!, style: TextStyle(color: colors.text)),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            child: AppText.caption(
              _error.isNotEmpty ? _error : '$kPasscodeMinLength-$kPasscodeMaxLength characters, letters and numbers allowed.',
              style: TextStyle(color: _error.isNotEmpty ? colors.expense : colors.secondary),
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
              child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextButton(
              onPressed: _resetToStatus,
              child: Text('Cancel', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verifyCurrentScreen(AppColors colors) {
    if (_method == 'biometric') {
      return _scaffold(
        colors,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText.heading('Verify to continue', style: TextStyle(color: colors.text)),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 32),
              child: AppText.caption(
                _error.isNotEmpty ? _error : 'Confirm with fingerprint or Face ID.',
                style: TextStyle(color: _error.isNotEmpty ? colors.expense : colors.secondary),
              ),
            ),
            if (_verifyingBiometric)
              CircularProgressIndicator(color: colors.primary)
            else
              ElevatedButton(
                onPressed: _runBiometricVerify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Try again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: TextButton(
                onPressed: _resetToStatus,
                child: Text('Cancel', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );
    }

    if (_method == 'passcode') {
      return _scaffold(
        colors,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppText.heading('Enter your passcode', style: TextStyle(color: colors.text)),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              child: AppText.caption(
                _error.isNotEmpty ? _error : 'Confirm your current passcode to continue.',
                style: TextStyle(color: _error.isNotEmpty ? colors.expense : colors.secondary),
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
                child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton(
                onPressed: _resetToStatus,
                child: Text('Cancel', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );
    }

    return _scaffold(
      colors,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText.heading('Enter your current PIN', style: TextStyle(color: colors.text)),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            child: AppText.caption(
              _error.isNotEmpty ? _error : 'Enter a $kPinLength-digit PIN.',
              style: TextStyle(color: _error.isNotEmpty ? colors.expense : colors.secondary),
            ),
          ),
          PinPad(length: kPinLength, value: _input, onChange: _handlePinInputChange, colors: colors),
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: TextButton(
              onPressed: _resetToStatus,
              child: Text('Cancel', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickMethodScreen(AppColors colors) {
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText.heading('Choose a lock method', style: TextStyle(color: colors.text)),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: AppText.caption(
                  _error.isNotEmpty ? _error : 'Pick how you want to unlock ExpenseTracker.',
                  style: TextStyle(color: _error.isNotEmpty ? colors.expense : colors.secondary),
                ),
              ),
              if (_verifyingBiometric)
                Padding(padding: const EdgeInsets.only(top: 12), child: CircularProgressIndicator(color: colors.primary))
              else ...[
                const SizedBox(height: 12),
                _methodOption(colors, icon: Icons.pin_outlined, label: 'PIN', subtitle: '4-digit code', onTap: () => _selectMethod('pin')),
                const SizedBox(height: 12),
                _methodOption(
                  colors,
                  icon: Icons.password_outlined,
                  label: 'Passcode',
                  subtitle: 'Letters and numbers',
                  onTap: () => _selectMethod('passcode'),
                ),
                if (_biometricAvailable) ...[
                  const SizedBox(height: 12),
                  _methodOption(
                    colors,
                    icon: _biometricIsFace ? Icons.face_outlined : Icons.fingerprint,
                    label: 'Fingerprint / Face ID',
                    subtitle: 'Use your device biometrics',
                    onTap: () => _selectMethod('biometric'),
                  ),
                ],
              ],
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: TextButton(
                  onPressed: _resetToStatus,
                  child: Text('Cancel', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodOption(
    AppColors colors, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(icon, size: 22, color: colors.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.body(label, style: TextStyle(color: colors.text)),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: AppText.caption(subtitle, style: TextStyle(color: colors.secondary)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: colors.placeholder),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusScreen(AppColors colors) {
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText.heading('Security Lock', style: TextStyle(color: colors.text)),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 20),
                child: AppText.caption(
                  _lockEnabled
                      ? 'Security Lock is on (${_methodLabel(_method)}). ExpenseTracker will ask you to unlock when you open or return to the app.'
                      : 'Require a PIN, passcode, or biometric to open ExpenseTracker.',
                  style: TextStyle(color: colors.secondary),
                ),
              ),
              if (_lockEnabled) ...[
                _actionButton('Change Method', colors.text, colors.card, _startChangeMethod),
                const SizedBox(height: 12),
                _actionButton('Turn off Security Lock', colors.expense, colors.card, _startDisable),
              ] else
                _actionButton('Turn on Security Lock', Colors.white, colors.primary, _startEnable),
              if (_lockEnabled && _method != 'biometric')
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: AppText.caption(
                    "If you forget your ${_methodLabel(_method).toLowerCase()}, you'll need to reinstall the app to regain access — there's no recovery flow.",
                    style: TextStyle(color: colors.placeholder),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String label, Color textColor, Color bgColor, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
          child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
