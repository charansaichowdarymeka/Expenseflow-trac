import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../firebase_config_status.dart';

class AppAuthProvider extends ChangeNotifier {
  User? _user;
  bool _loading = isFirebaseConfigured;

  AppAuthProvider() {
    if (!isFirebaseConfigured) return;
    try {
      FirebaseAuth.instance.authStateChanges().listen((next) {
        _user = next;
        _loading = false;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Failed to attach auth state listener: $e');
      _loading = false;
    }
  }

  User? get user => _user;
  bool get loading => _loading;
  bool get configured => isFirebaseConfigured;

  Future<void> signIn(String email, String password) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> signUp(String email, String password) async {
    await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> resetPassword(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  }
}

String authErrorMessage(Object error) {
  final code = error is FirebaseAuthException ? error.code : '';
  const map = {
    'invalid-email': 'That email address looks invalid.',
    'user-disabled': 'This account has been disabled.',
    'user-not-found': 'No account found with that email.',
    'wrong-password': 'Incorrect password.',
    'invalid-credential': 'Incorrect email or password.',
    'email-already-in-use': 'An account with that email already exists.',
    'weak-password': 'Password should be at least 6 characters.',
    'network-request-failed': 'Network error. Check your connection and try again.',
    'too-many-requests': 'Too many attempts. Try again later.',
  };
  return map[code] ?? 'Something went wrong. Please try again.';
}
