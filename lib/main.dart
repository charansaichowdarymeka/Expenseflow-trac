import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/app_theme.dart';
import 'firebase_config_status.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/display_prefs_provider.dart';
import 'providers/premium_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/weekly_reminder_provider.dart';
import 'router/app_router.dart';
import 'services/push_notifications.dart';
import 'widgets/app_lock_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (details) => _CrashScreen(error: details.exception);
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Unhandled Flutter error: ${details.exception}');
  };

  if (isFirebaseConfigured) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      debugPrint('Firebase failed to initialize, continuing in local-only mode: $e');
    }
  }

  initPushNotifications();

  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppThemeProvider()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => DisplayPrefsProvider()),
        ChangeNotifierProvider(create: (_) => WeeklyReminderProvider()),
        ChangeNotifierProvider(create: (_) => PremiumProvider()),
      ],
      child: Builder(
        builder: (context) {
          final themeProvider = context.watch<AppThemeProvider>();
          final brightness = MediaQuery.platformBrightnessOf(context);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            themeProvider.updateSystemBrightness(brightness);
          });

          return MaterialApp.router(
            title: 'ExpenseTracker',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(kLightColors, Brightness.light),
            darkTheme: buildAppTheme(kDarkColors, Brightness.dark),
            themeMode: themeProvider.mode == AppThemeMode.light
                ? ThemeMode.light
                : themeProvider.mode == AppThemeMode.dark
                    ? ThemeMode.dark
                    : ThemeMode.system,
            routerConfig: appRouter,
            builder: (context, child) {
              return AppLockGate(child: child ?? const SizedBox.shrink());
            },
          );
        },
      ),
    );
  }
}

class _CrashScreen extends StatelessWidget {
  final Object error;
  const _CrashScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kLightColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Something went wrong',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kLightColors.text),
              ),
              const SizedBox(height: 8),
              Text(
                'The app hit an unexpected error. Your data is safe on this device.',
                textAlign: TextAlign.center,
                style: TextStyle(color: kLightColors.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
