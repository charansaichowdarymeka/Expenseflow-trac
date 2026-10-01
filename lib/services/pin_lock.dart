import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

const String _kPinKey = 'expensetracker_pin';
const String _kPasscodeKey = 'expensetracker_passcode';
const int kPinLength = 4;
const int kPasscodeMinLength = 4;
const int kPasscodeMaxLength = 20;

final FlutterSecureStorage _storage = const FlutterSecureStorage();
final LocalAuthentication _localAuth = LocalAuthentication();

Future<bool> hasPin() async {
  final value = await _storage.read(key: _kPinKey);
  return value != null && value.isNotEmpty;
}

Future<void> setPin(String pin) async {
  await _storage.write(key: _kPinKey, value: pin);
}

Future<bool> verifyPin(String pin) async {
  final stored = await _storage.read(key: _kPinKey);
  return stored != null && stored == pin;
}

Future<void> clearPin() async {
  await _storage.delete(key: _kPinKey);
}

Future<bool> hasPasscode() async {
  final value = await _storage.read(key: _kPasscodeKey);
  return value != null && value.isNotEmpty;
}

Future<void> setPasscode(String passcode) async {
  await _storage.write(key: _kPasscodeKey, value: passcode);
}

Future<bool> verifyPasscode(String passcode) async {
  final stored = await _storage.read(key: _kPasscodeKey);
  return stored != null && stored == passcode;
}

Future<void> clearPasscode() async {
  await _storage.delete(key: _kPasscodeKey);
}

/// Whether this device has biometrics (fingerprint/face) enrolled and ready to use.
Future<bool> isBiometricAvailable() async {
  try {
    final supported = await _localAuth.isDeviceSupported();
    if (!supported) return false;
    final canCheck = await _localAuth.canCheckBiometrics;
    if (!canCheck) return false;
    final available = await _localAuth.getAvailableBiometrics();
    return available.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// True if the enrolled biometric is Face ID (iOS) / face unlock (Android),
/// used only to pick a friendlier label — either kind is accepted at auth time.
Future<bool> isFaceBiometric() async {
  try {
    final available = await _localAuth.getAvailableBiometrics();
    return available.contains(BiometricType.face) && !available.contains(BiometricType.fingerprint);
  } catch (_) {
    return false;
  }
}

Future<bool> authenticateWithBiometrics(String reason) async {
  try {
    return await _localAuth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
    );
  } catch (_) {
    return false;
  }
}
