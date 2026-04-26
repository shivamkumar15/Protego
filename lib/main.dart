import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'theme_mode_scope.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/emergency_contacts_setup_screen.dart';
import 'screens/verify_email_screen.dart';
import 'services/emergency_contacts_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProtegoApp());
}

class ProtegoApp extends StatefulWidget {
  const ProtegoApp({super.key});

  @override
  State<ProtegoApp> createState() => _ProtegoAppState();
}

class _ProtegoAppState extends State<ProtegoApp> {
  static const _themeModePrefsKey = 'theme_mode';
  final ValueNotifier<ThemeMode> _themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  @override
  void initState() {
    super.initState();
    _loadSavedThemeMode();
    _themeMode.addListener(_persistThemeMode);
  }

  @override
  void dispose() {
    _themeMode.removeListener(_persistThemeMode);
    _themeMode.dispose();
    super.dispose();
  }

  Future<void> _loadSavedThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getString(_themeModePrefsKey);
    if (savedValue == null) return;

    final savedMode = _themeModeFromString(savedValue);
    if (savedMode != null) {
      _themeMode.value = savedMode;
    }
  }

  Future<void> _persistThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModePrefsKey, _themeMode.value.name);
  }

  ThemeMode? _themeModeFromString(String value) {
    switch (value) {
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return null;
    }
  }

  ThemeData _buildLightTheme() {
    const primary = Color(0xFFF71180);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: primary,
        surface: Colors.white,
        onSurface: Color(0xFF0F172A),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
      ),
      fontFamily: 'Inter',
    );
  }

  ThemeData _buildDarkTheme() {
    const primary = Color(0xFFF71180);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primary,
        surface: Color(0xFF0A0A0A),
        onSurface: Color(0xFFF5F5F5),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF101010),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
      ),
      fontFamily: 'Inter',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ThemeModeScope(
      notifier: _themeMode,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: _themeMode,
        builder: (context, mode, _) {
          return MaterialApp(
            title: 'Protego',
            debugShowCheckedModeBanner: false,
            themeMode: mode,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }
        if (snapshot.hasData) {
          final user = snapshot.data!;
          final isAllowedSession =
              user.phoneNumber != null || user.emailVerified;
          if (isAllowedSession) {
            return FutureBuilder<bool>(
              future: EmergencyContactsService().shouldShowOnboarding(),
              builder: (context, onboardingSnapshot) {
                if (onboardingSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                }
                if (onboardingSnapshot.data ?? false) {
                  return const EmergencyContactsSetupScreen();
                }
                return const HomeScreen();
              },
            );
          }
          return const VerifyEmailScreen();
        }
        return const SignUpScreen();
      },
    );
  }
}
