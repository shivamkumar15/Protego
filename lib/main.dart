import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProtegoApp());
}

class ProtegoApp extends StatelessWidget {
  const ProtegoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guardian Safety App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF131313),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFB4AA),
          surface: Color(0xFF131313),
          onSurface: Color(0xFFE2E2E2),
        ),
        textTheme: TextTheme(
          displayLarge: GoogleFonts.manrope(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: const Color(0xFFE2E2E2),
          ),
          bodyLarge: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: const Color(0xFFE7BDB7),
          ),
          labelLarge: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: const Color(0xFFFFB4AA),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/// Listens to Firebase auth state and routes accordingly.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFF131313),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/logo.png', height: 80),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(
                    color: Color(0xFFFFB4AA),
                    strokeWidth: 2.5,
                  ),
                ],
              ),
            ),
          );
        }

        // User is signed in → Home
        if (snapshot.hasData) {
          return const HomeScreen();
        }

        // Not signed in → Sign Up
        return const SignUpScreen();
      },
    );
  }
}
