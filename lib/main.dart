import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/signup_screen.dart';

void main() {
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
      home: const SignUpScreen(),
    );
  }
}
