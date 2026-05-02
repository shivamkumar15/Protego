import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'screens/emergency_contacts_setup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/username_setup_screen.dart';
import 'screens/verify_email_screen.dart';
import 'services/emergency_contacts_service.dart';
import 'services/username_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _hasProfileDetails(String uid) async {
    final profile = await UsernameService().getPublicProfileForUserId(uid);
    if (profile == null) {
      return false;
    }
    // Require only phone number to consider profile complete.
    // date_of_birth may fail to persist if the column is missing from the
    // Supabase table, so we must not gate the entire app on it.
    final phone = (profile.phoneNumber ?? '').trim();
    return phone.isNotEmpty;
  }

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
            return StreamBuilder<String?>(
              stream: UsernameService().usernameStreamForUserId(user.uid),
              builder: (context, usernameSnapshot) {
                if (usernameSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                }

                final username = usernameSnapshot.data;
                return FutureBuilder<bool>(
                  future: _hasProfileDetails(user.uid),
                  builder: (context, profileSnapshot) {
                    if (profileSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Scaffold(
                        body: Center(
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      );
                    }

                    final hasUsername = (username ?? '').trim().isNotEmpty;
                    final hasProfileDetails = profileSnapshot.data ?? false;

                    if (!hasUsername || !hasProfileDetails) {
                      return UsernameSetupScreen(
                        user: user,
                        prefilledUsername: hasUsername ? username : null,
                      );
                    }

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
                  },
                );
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
