import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final user = FirebaseAuth.instance.currentUser;
    final authService = AuthService();

    return Scaffold(
      body: Stack(
        children: [
          // Background Blobs
          Positioned(
            top: size.height * 0.05,
            right: -size.width * 0.1,
            child: Container(
              width: size.width * 0.4,
              height: size.height * 0.4,
              decoration: BoxDecoration(
                color: const Color(0xFF0a2f1f).withOpacity(0.4),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.15,
            left: -size.width * 0.1,
            child: Container(
              width: size.width * 0.5,
              height: size.height * 0.5,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Backdrop blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PROTEGO',
                              style: theme.textTheme.labelLarge?.copyWith(
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Welcome,',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                            Text(
                              user?.displayName ?? 'Guardian',
                              style: theme.textTheme.displayLarge?.copyWith(
                                fontSize: 28,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Avatar
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.primary.withOpacity(0.3),
                              theme.colorScheme.primary.withOpacity(0.1),
                            ],
                          ),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(user),
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Shield Status Card
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B1B),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Shield icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF2E7D32).withOpacity(0.3),
                                const Color(0xFF2E7D32).withOpacity(0.05),
                              ],
                            ),
                            border: Border.all(
                              color: const Color(0xFF2E7D32).withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.shield,
                            color: Color(0xFF66BB6A),
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Shield Active',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF66BB6A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your protection is enabled',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // User info
                        _buildInfoRow(
                          theme: theme,
                          icon: Icons.alternate_email,
                          label: 'Email',
                          value: user?.email ?? 'Not set',
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          theme: theme,
                          icon: Icons.phone_android,
                          label: 'Phone',
                          value: user?.phoneNumber ?? 'Not set',
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          theme: theme,
                          icon: Icons.fingerprint,
                          label: 'UID',
                          value: user?.uid.substring(0, 12) ?? '—',
                          mono: true,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Sign Out Button
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFD93627).withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD93627).withOpacity(0.1),
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.logout,
                          color: Color(0xFFFF5545), size: 20),
                      label: Text(
                        'Sign Out',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFFF5545),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () async {
                        await authService.signOut();
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Decorative Bottom Line
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFF66BB6A).withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(User? user) {
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      final parts = user.displayName!.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return parts[0][0].toUpperCase();
    }
    if (user?.email != null) {
      return user!.email![0].toUpperCase();
    }
    return 'G';
  }

  Widget _buildInfoRow({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
    bool mono = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.3), size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.8),
                fontFamily: mono ? 'monospace' : null,
                fontSize: mono ? 12 : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
