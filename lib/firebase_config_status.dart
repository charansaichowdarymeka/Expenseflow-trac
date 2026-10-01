import 'firebase_options.dart';

/// Whether a real Firebase project has been wired in via `flutterfire configure`.
///
/// Kept separate from `firebase_options.dart` because that file is regenerated
/// wholesale by the FlutterFire CLI on every `flutterfire configure` run, which
/// would silently drop anything hand-added to it.
bool get isFirebaseConfigured => DefaultFirebaseOptions.currentPlatform.apiKey.isNotEmpty;
