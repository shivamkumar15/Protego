import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/emergency_contacts_setup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/username_setup_screen.dart';
import 'screens/verify_email_screen.dart';
import 'services/emergency_contacts_service.dart';
import 'services/username_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// Cached routing future keyed by UID so we don't re-fire network requests
  /// on every StreamBuilder rebuild.
  String? _cachedUid;
  Future<_RoutingDecision>? _cachedRoutingFuture;

  /// Returns a cached future for [uid], only creating a new one when the UID
  /// changes (i.e. a different user signs in).
  Future<_RoutingDecision> _getRoutingFuture(String uid) {
    if (_cachedUid != uid || _cachedRoutingFuture == null) {
      _cachedUid = uid;
      _cachedRoutingFuture = _resolveRouting(uid);
    }
    return _cachedRoutingFuture!;
  }

  /// Runs username lookup, profile-completeness check, and onboarding check
  /// **in parallel** instead of sequentially.  This cuts the visible loading
  /// time from 3 serial round-trips down to one parallel batch.
  Future<_RoutingDecision> _resolveRouting(String uid) async {
    final results = await Future.wait([
      UsernameService().getUsernameForUserId(uid),
      _hasProfileDetails(uid),
      EmergencyContactsService().shouldShowOnboarding(),
    ]);

    return _RoutingDecision(
      username: results[0] as String?,
      hasProfileDetails: results[1] as bool,
      shouldShowOnboarding: results[2] as bool,
    );
  }

  Future<bool> _hasProfileDetails(String uid) async {
    final profile = await UsernameService().getPublicProfileForUserId(uid);
    if (profile == null) {
      return false;
    }

    // While we have the profile, cache the photo path so HomeScreen doesn't
    // need to make another round-trip to Supabase just for the avatar.
    final photoPath = (profile.profilePhotoPath ?? '').trim();
    if (photoPath.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_photo_$uid', photoPath);
      } catch (_) {
        // Non-critical; HomeScreen will fetch if cache is empty.
      }
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
          return _loadingScaffold(context);
        }

        if (!snapshot.hasData) {
          // Clear cached future when user signs out.
          _cachedUid = null;
          _cachedRoutingFuture = null;
          return const SignUpScreen();
        }

        final user = snapshot.data!;
        final isAllowedSession =
            user.phoneNumber != null || user.emailVerified;

        if (!isAllowedSession) {
          return const VerifyEmailScreen();
        }

        return FutureBuilder<_RoutingDecision>(
          future: _getRoutingFuture(user.uid),
          builder: (context, routingSnapshot) {
            if (routingSnapshot.connectionState ==
                ConnectionState.waiting) {
              return _loadingScaffold(context);
            }

            final decision = routingSnapshot.data;
            if (decision == null) {
              // Future completed with an error — fall back to loading.
              return _loadingScaffold(context);
            }

            final hasUsername =
                (decision.username ?? '').trim().isNotEmpty;

            if (!hasUsername || !decision.hasProfileDetails) {
              return UsernameSetupScreen(
                user: user,
                prefilledUsername:
                    hasUsername ? decision.username : null,
              );
            }

            if (decision.shouldShowOnboarding) {
              return const EmergencyContactsSetupScreen();
            }

            return const HomeScreen();
          },
        );
      },
    );
  }

  Widget _loadingScaffold(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _RoutingDecision {
  const _RoutingDecision({
    required this.username,
    required this.hasProfileDetails,
    required this.shouldShowOnboarding,
  });

  final String? username;
  final bool hasProfileDetails;
  final bool shouldShowOnboarding;
}
