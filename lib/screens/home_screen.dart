import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme_mode_scope.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const _titles = <String>[
    'Home',
    'Live Map',
    'Emergency Contacts',
    'Profile',
    'Settings',
  ];

  static const _navItems = <_BottomNavItem>[
    _BottomNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
    ),
    _BottomNavItem(
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
      label: 'Live Map',
    ),
    _BottomNavItem(
      icon: Icons.contact_phone_outlined,
      activeIcon: Icons.contact_phone,
      label: 'Contacts',
    ),
    _BottomNavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profile',
    ),
    _BottomNavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final authService = AuthService();
    final themeModeController = ThemeModeScope.of(context);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          _titles[_currentIndex],
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_currentIndex == 4)
            PopupMenuButton<ThemeMode>(
              tooltip: 'Theme mode',
              icon: Icon(Icons.palette_outlined,
                  color: theme.colorScheme.onSurface),
              onSelected: (mode) => themeModeController.value = mode,
              itemBuilder: (context) => [
                const PopupMenuItem<ThemeMode>(
                  value: ThemeMode.system,
                  child: Text('System'),
                ),
                const PopupMenuItem<ThemeMode>(
                  value: ThemeMode.light,
                  child: Text('Light'),
                ),
                const PopupMenuItem<ThemeMode>(
                  value: ThemeMode.dark,
                  child: Text('Dark'),
                ),
              ],
            ),
          IconButton(
            icon: Icon(Icons.logout, color: theme.colorScheme.onSurface),
            onPressed: authService.signOut,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB),
            height: 1,
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeTab(user: user),
          const _LiveMapTab(),
          const _EmergencyContactsTab(),
          _ProfileTab(user: user),
          _SettingsTab(themeModeController: themeModeController),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: _AnimatedBottomNavBar(
          items: _navItems,
          currentIndex: _currentIndex,
          onTap: (index) {
            if (_currentIndex == index) return;
            setState(() => _currentIndex = index);
          },
        ),
      ),
    );
  }
}

class _BottomNavItem {
  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _AnimatedBottomNavBar extends StatefulWidget {
  const _AnimatedBottomNavBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<_BottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  State<_AnimatedBottomNavBar> createState() => _AnimatedBottomNavBarState();
}

class _AnimatedBottomNavBarState extends State<_AnimatedBottomNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = Tween<double>(
      begin: widget.currentIndex.toDouble(),
      end: widget.currentIndex.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  }

  @override
  void didUpdateWidget(covariant _AnimatedBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _animation = Tween<double>(
        begin: _animation.value, // Start from current animated position
        end: widget.currentIndex.toDouble(),
      ).animate(
        CurvedAnimation(
          parent: _controller,
          // Elastic curve creates the "forth and back" sloshing water effect
          curve: Curves.elasticOut,
        ),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navBackground = isDark ? const Color(0xFF0E0E0E) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final iconColor =
        isDark ? const Color(0xFFB8B8B8) : const Color(0xFF111827);

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemCount = widget.items.length;
        final slotWidth = constraints.maxWidth / itemCount;

        return SizedBox(
          height: 84,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              final currentIndexFloat = _animation.value;

              // Allow raw center to overshoot so the elastic wobble
              // is fully visible at the edges (the "forth and back" water effect).
              final notchCenterX =
                  (slotWidth * currentIndexFloat) + (slotWidth / 2);

              // The ball stays a perfect circle and smoothly glides with the notch
              const ballSize = 16.0;
              const ballTop = -2.0; // Floats slightly up
              const notchDepth = 18.0;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    top: 14,
                    child: CustomPaint(
                      painter: _LiquidNavBarPainter(
                        backgroundColor: navBackground,
                        borderColor: borderColor,
                        notchCenterX: notchCenterX,
                        notchDepth: notchDepth,
                        showShadow: true,
                      ),
                      child: Row(
                        children: List.generate(itemCount, (index) {
                          final item = widget.items[index];
                          final selected = index == widget.currentIndex;
                          return Expanded(
                            child: Semantics(
                              button: true,
                              label: item.label,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => widget.onTap(index),
                                child: SizedBox(
                                  height: 72,
                                  child: Center(
                                    child: AnimatedScale(
                                      duration:
                                          const Duration(milliseconds: 400),
                                      curve: Curves.easeOutBack,
                                      scale: selected ? 1.15 : 1,
                                      child: Icon(
                                        selected ? item.activeIcon : item.icon,
                                        color: selected
                                            ? theme.colorScheme.primary
                                            : iconColor,
                                        size: selected ? 28 : 26,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  Positioned(
                    left: notchCenterX - (ballSize / 2),
                    top: ballTop,
                    child: IgnorePointer(
                      child: Container(
                        width: ballSize,
                        height: ballSize,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.45),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _LiquidNavBarPainter extends CustomPainter {
  _LiquidNavBarPainter({
    required this.backgroundColor,
    required this.borderColor,
    required this.notchCenterX,
    required this.notchDepth,
    required this.showShadow,
  });

  final Color backgroundColor;
  final Color borderColor;
  final double notchCenterX;
  final double notchDepth;
  final bool showShadow;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 24.0;
    const notchWidth = 84.0;

    // The raw center of the notch, which can freely bounce past the edges
    final notchStart = notchCenterX - (notchWidth / 2);
    final notchEnd = notchCenterX + (notchWidth / 2);

    // 1. Create the base rounded rectangle
    final baseRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(radius),
    );
    final basePath = Path()..addRRect(baseRect);

    // 2. Create the cutout shape for the liquid notch
    final cutoutPath = Path()
      ..moveTo(notchStart, -50) // Start high above the bar
      ..lineTo(notchStart, 0)
      // First half of the liquid notch
      ..cubicTo(
        notchStart + (notchWidth * 0.35),
        0,
        notchCenterX - (notchWidth * 0.25),
        notchDepth,
        notchCenterX,
        notchDepth,
      )
      // Second half of the liquid notch
      ..cubicTo(
        notchCenterX + (notchWidth * 0.25),
        notchDepth,
        notchEnd - (notchWidth * 0.35),
        0,
        notchEnd,
        0,
      )
      ..lineTo(notchEnd, -50) // Go back up
      ..close();

    // 3. Subtract the cutout from the base shape.
    // This perfectly handles the notch overlapping the corner radius (no bulges!)
    final finalPath = Path.combine(
      PathOperation.difference,
      basePath,
      cutoutPath,
    );

    if (showShadow) {
      canvas.drawShadow(finalPath, Colors.black, 16, true);
    }

    final fillPaint = Paint()..color = backgroundColor;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawPath(finalPath, fillPaint);
    canvas.drawPath(finalPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidNavBarPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.notchCenterX != notchCenterX ||
        oldDelegate.notchDepth != notchDepth ||
        oldDelegate.showShadow != showShadow;
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Overview',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _SurfaceCard(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.shield_outlined,
                    color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Protection Active',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? user?.phoneNumber ?? 'Guardian connected',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFFA3A3A3)
                            : const Color(0xFF6B7280),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveMapTab extends StatelessWidget {
  const _LiveMapTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.place_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Live map tracking',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Map integration section is ready. Connect it to your realtime location stream.',
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmergencyContactsTab extends StatelessWidget {
  const _EmergencyContactsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        _EmergencyContactTile(name: 'Police', number: '100'),
        SizedBox(height: 10),
        _EmergencyContactTile(name: 'Ambulance', number: '102'),
        SizedBox(height: 10),
        _EmergencyContactTile(name: 'Women Helpline', number: '1091'),
      ],
    );
  }
}

class _EmergencyContactTile extends StatelessWidget {
  const _EmergencyContactTile({required this.name, required this.number});

  final String name;
  final String number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SurfaceCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.call, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$name - $number',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Icon(Icons.arrow_forward_ios,
              size: 14, color: theme.colorScheme.onSurface),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _ProfileRow(label: 'Name', value: user?.displayName ?? 'Not set'),
              _ProfileRow(label: 'Email', value: user?.email ?? 'Not linked'),
              _ProfileRow(
                  label: 'Phone', value: user?.phoneNumber ?? 'Not linked'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.themeModeController});

  final ValueNotifier<ThemeMode> themeModeController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme mode',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.settings_suggest_outlined),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: <ThemeMode>{themeModeController.value},
                onSelectionChanged: (selection) {
                  themeModeController.value = selection.first;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
