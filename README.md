# ExpenseTracker

A personal expense tracker built with Flutter: expense/income tracking,
categories, budgets, recurring expenses, split expenses, reports & charts,
notifications, PIN lock, backup/export, and optional Firebase auth + cloud
sync.

Migrated from an earlier Expo/React Native version of this app.

## Get started

```bash
flutter pub get
flutter run
```

## Cloud Sync / Login setup

Cloud sync and login are optional and off by default. To enable them, see the
setup steps in [lib/firebase_options.dart](lib/firebase_options.dart) — you'll
need a Firebase project with Email/Password auth and Firestore enabled.
