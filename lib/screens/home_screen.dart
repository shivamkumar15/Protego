import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlng;
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/emergency_contacts_service.dart';
import '../services/sos_recording_service.dart';
import '../theme_mode_scope.dart';
import 'emergency_contact_editor_sheet.dart';
import 'sos_recordings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;
  final SosRecordingService _sosRecordingService = SosRecordingService();
  bool _isSosActive = false;
  String? _activeSosRecordingPath;

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
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  Future<void> _handleSosActivated() async {
    try {
      final recordingPath = await _sosRecordingService.startRecording();
      if (!mounted) {
        return;
      }
      setState(() {
        _isSosActive = true;
        _activeSosRecordingPath = recordingPath;
        _currentIndex = 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Help is on the way. SOS recording started.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopSos() async {
    final recordingPath = await _sosRecordingService.stopRecording();
    final savedPath = recordingPath ?? _activeSosRecordingPath;
    if (!mounted) {
      return;
    }
    setState(() {
      _isSosActive = false;
      _activeSosRecordingPath = savedPath;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedPath == null
              ? 'SOS stopped. Recording ended.'
              : 'SOS stopped. Recording saved to $savedPath',
        ),
      ),
    );
  }

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
          _HomeTab(
            user: user,
            isSosActive: _isSosActive,
            onSosActivated: _handleSosActivated,
            onStopSos: _stopSos,
          ),
          _LiveMapTab(
            isSosActive: _isSosActive,
            onStopSos: _stopSos,
          ),
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
  const _HomeTab({
    required this.user,
    required this.isSosActive,
    required this.onSosActivated,
    required this.onStopSos,
  });

  final User? user;
  final bool isSosActive;
  final Future<void> Function() onSosActivated;
  final Future<void> Function() onStopSos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        const SizedBox(height: 18),
        _SosHoldButton(
          isSosActive: isSosActive,
          onActivated: onSosActivated,
          onStop: onStopSos,
        ),
      ],
    );
  }
}

class _SosHoldButton extends StatefulWidget {
  const _SosHoldButton({
    required this.isSosActive,
    required this.onActivated,
    required this.onStop,
  });

  final bool isSosActive;
  final Future<void> Function() onActivated;
  final Future<void> Function() onStop;

  @override
  State<_SosHoldButton> createState() => _SosHoldButtonState();
}

class _SosHoldButtonState extends State<_SosHoldButton>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _holdController;
  bool _isHolding = false;
  bool _activated = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);

    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_activated) {
          _activated = true;
          _activateSos();
        }
      });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _holdController.dispose();
    super.dispose();
  }

  void _startHold() {
    if (_isHolding || widget.isSosActive || _isProcessing) return;
    setState(() {
      _isHolding = true;
      _activated = false;
    });
    _holdController.forward(from: 0);
  }

  void _endHold() {
    if (!_isHolding) return;
    setState(() {
      _isHolding = false;
    });
    if (_holdController.isCompleted) {
      _holdController.value = 0;
      return;
    }
    _holdController.animateBack(0,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  Future<void> _activateSos() async {
    if (_isProcessing) {
      return;
    }
    setState(() {
      _isProcessing = true;
      _isHolding = false;
    });
    try {
      await widget.onActivated();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _holdController.value = 0;
        });
      }
    }
  }

  Future<void> _stopSos() async {
    if (_isProcessing) {
      return;
    }
    setState(() {
      _isProcessing = true;
    });
    try {
      await widget.onStop();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emergency SOS',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.isSosActive
                ? 'SOS is active. Voice recording is running and saved locally.'
                : 'Press and hold for 2 seconds to trigger emergency assistance.',
            style: TextStyle(
              color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: widget.isSosActive
                ? SizedBox(
                    width: 210,
                    child: FilledButton.icon(
                      onPressed: _isProcessing ? null : _stopSos,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.stop_circle_outlined),
                      label: const Text(
                        'Stop SOS',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                : GestureDetector(
                    onTapDown: (_) => _startHold(),
                    onTapUp: (_) => _endHold(),
                    onTapCancel: _endHold,
                    child: AnimatedBuilder(
                      animation:
                          Listenable.merge([_pulseController, _holdController]),
                      builder: (context, _) {
                        final pulse = 1 + (_pulseController.value * 0.05);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.scale(
                              scale: pulse,
                              child: Container(
                                width: 148,
                                height: 148,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.red.withValues(
                                      alpha: _isHolding ? 0.25 : 0.18),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 136,
                              height: 136,
                              child: CircularProgressIndicator(
                                value: _holdController.value,
                                strokeWidth: 6,
                                backgroundColor: isDark
                                    ? const Color(0xFF2A2A2A)
                                    : const Color(0xFFE5E7EB),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.red),
                              ),
                            ),
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.red.shade500,
                                    Colors.red.shade800,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.4),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  'SOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              widget.isSosActive
                  ? 'Recording will stop automatically when SOS is stopped'
                  : _isHolding
                      ? 'Hold... ${(_holdController.value * 2).clamp(0, 2).toStringAsFixed(1)}s / 2.0s'
                      : 'Release before 2 seconds to cancel',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _isHolding
                    ? Colors.red
                    : (isDark
                        ? const Color(0xFFA3A3A3)
                        : const Color(0xFF6B7280)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveMapTab extends StatefulWidget {
  const _LiveMapTab({required this.isSosActive, required this.onStopSos});

  final bool isSosActive;
  final Future<void> Function() onStopSos;

  @override
  State<_LiveMapTab> createState() => _LiveMapTabState();
}

class _LiveMapTabState extends State<_LiveMapTab> with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  static const _walkingSpeedMetersPerSecond = 1.4;
  StreamSubscription<Position>? _positionSubscription;
  Position? _position;
  latlng.LatLng? _nearestPoliceStation;
  latlng.LatLng? _lastRouteFetchOrigin;
  String _nearestPoliceStationName = 'Nearest police station';
  List<latlng.LatLng> _routePoints = const [];
  double? _routeDistanceKm;
  double? _routeEtaMinutes;
  bool _isLoading = true;
  bool _isRequestingPermission = false;
  bool _isFetchingPoliceRoute = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocationTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initLocationTracking();
    }
  }

  void _moveCameraTo(latlng.LatLng target, {double? zoom}) {
    try {
      _mapController.move(target, zoom ?? _mapController.camera.zoom);
    } catch (_) {
      // Map may not be attached yet.
    }
  }

  Future<void> _initLocationTracking() async {
    if (_isRequestingPermission) return;
    _isRequestingPermission = true;

    setState(() {
      _isLoading = _position == null;
      _errorMessage = null;
    });

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Location is off. Please turn on phone location and return to the app.';
      });
      _isRequestingPermission = false;
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Location permission is required to show your live location.';
      });
      _isRequestingPermission = false;
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Location permission is permanently denied. Enable it from app settings.';
      });
      _isRequestingPermission = false;
      return;
    }

    try {
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null && mounted) {
        setState(() {
          _position = cached;
          _isLoading = false;
        });
        _moveCameraTo(
          latlng.LatLng(cached.latitude, cached.longitude),
          zoom: 15.5,
        );
        await _fetchNearestPoliceRoute(cached, forceRefresh: true);
      }

      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (!mounted) return;
      setState(() {
        _position = current;
        _isLoading = false;
      });
      _moveCameraTo(
        latlng.LatLng(current.latitude, current.longitude),
        zoom: 16,
      );
      await _fetchNearestPoliceRoute(current, forceRefresh: true);

      await _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 8,
        ),
      ).listen((position) {
        if (!mounted) return;
        setState(() => _position = position);
        _moveCameraTo(latlng.LatLng(position.latitude, position.longitude));
        _fetchNearestPoliceRoute(position);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _position == null
            ? 'Unable to fetch location right now. Please try again.'
            : null;
      });
    } finally {
      _isRequestingPermission = false;
    }
  }

  Future<void> _fetchNearestPoliceRoute(
    Position position, {
    bool forceRefresh = false,
  }) async {
    if (_isFetchingPoliceRoute) {
      return;
    }

    if (!forceRefresh && _lastRouteFetchOrigin != null) {
      final movedDistance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        _lastRouteFetchOrigin!.latitude,
        _lastRouteFetchOrigin!.longitude,
      );
      if (movedDistance < 150) {
        return;
      }
    }

    _isFetchingPoliceRoute = true;
    _lastRouteFetchOrigin =
        latlng.LatLng(position.latitude, position.longitude);
    try {
      final stations = await _findNearestPoliceStations(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (stations.isEmpty) {
        if (!mounted || _nearestPoliceStation != null) return;
        setState(() {
          _nearestPoliceStationName = 'No nearby police station found';
          _routePoints = const [];
          _routeDistanceKm = null;
          _routeEtaMinutes = null;
        });
        return;
      }

      final origin = latlng.LatLng(position.latitude, position.longitude);
      _PoliceStation? selectedStation;
      _RouteInfo? selectedRoute;
      final candidateStations = stations.take(4).toList();
      var walkingGraph = await _buildWalkingGraph(
        origin: origin,
        destinations:
            candidateStations.map((station) => station.position).toList(),
      );

      Future<void> chooseBestRoute() async {
        for (final station in candidateStations) {
          final route = await _buildRouteToPoliceStation(
            from: origin,
            to: station.position,
            graph: walkingGraph,
          );
          if (route == null && selectedStation == null) {
            selectedStation = station;
            continue;
          }
          if (route == null) {
            continue;
          }
          final selectedRouteDuration =
              selectedRoute?.durationSeconds ?? double.infinity;
          if (selectedRoute == null ||
              (route.durationSeconds ?? double.infinity) <
                  selectedRouteDuration) {
            selectedStation = station;
            selectedRoute = route;
          }
        }
      }

      await chooseBestRoute();

      if (selectedRoute == null && candidateStations.isNotEmpty) {
        walkingGraph = await _buildWalkingGraph(
          origin: origin,
          destinations:
              candidateStations.map((station) => station.position).toList(),
          paddingDegrees: 0.02,
        );
        await chooseBestRoute();
      }

      final station = selectedStation ?? stations.first;

      if (!mounted) return;
      final distanceMeters = selectedRoute?.distanceMeters;
      final durationSeconds = selectedRoute?.durationSeconds;
      setState(() {
        _nearestPoliceStation = station.position;
        _nearestPoliceStationName = station.name;
        _routePoints = selectedRoute?.points ??
            [
              origin,
              station.position,
            ];
        _routeDistanceKm =
            distanceMeters != null ? distanceMeters / 1000 : null;
        _routeEtaMinutes =
            durationSeconds != null ? durationSeconds / 60 : null;
      });
    } catch (_) {
      if (!mounted || _nearestPoliceStation != null) return;
      setState(() {
        _nearestPoliceStationName = 'Unable to load nearest police station';
      });
    } finally {
      _isFetchingPoliceRoute = false;
    }
  }

  Future<List<_PoliceStation>> _findNearestPoliceStations({
    required double latitude,
    required double longitude,
  }) async {
    final query =
        '[out:json][timeout:20];(node["amenity"="police"](around:7000,$latitude,$longitude);way["amenity"="police"](around:7000,$latitude,$longitude););out center 1;';
    final uri =
        Uri.https('overpass-api.de', '/api/interpreter', {'data': query});
    final response = await http.get(uri, headers: {
      'User-Agent': 'Protego/1.0 (safety app)',
      'Accept': 'application/json',
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return const [];
    }

    final elements = decoded['elements'];
    if (elements is! List || elements.isEmpty) {
      return const [];
    }

    final stations = <_PoliceStationDistance>[];
    for (final item in elements) {
      if (item is! Map<String, dynamic>) continue;

      final lat = (item['lat'] as num?)?.toDouble() ??
          (item['center'] is Map<String, dynamic>
              ? ((item['center']['lat'] as num?)?.toDouble())
              : null);
      final lon = (item['lon'] as num?)?.toDouble() ??
          (item['center'] is Map<String, dynamic>
              ? ((item['center']['lon'] as num?)?.toDouble())
              : null);
      if (lat == null || lon == null) continue;

      final tags = item['tags'];
      final name = tags is Map<String, dynamic>
          ? (tags['name'] as String?) ?? 'Nearby police station'
          : 'Nearby police station';
      stations.add(
        _PoliceStationDistance(
          station: _PoliceStation(
            name: name,
            position: latlng.LatLng(lat, lon),
          ),
          straightLineDistance: Geolocator.distanceBetween(
            latitude,
            longitude,
            lat,
            lon,
          ),
        ),
      );
    }

    stations.sort(
      (a, b) => a.straightLineDistance.compareTo(b.straightLineDistance),
    );
    return stations.map((entry) => entry.station).take(6).toList();
  }

  Future<_RouteInfo?> _buildRouteToPoliceStation({
    required latlng.LatLng from,
    required latlng.LatLng to,
    required _WalkingGraph graph,
  }) async {
    if (graph.nodes.length < 2) {
      return null;
    }

    final startCandidates = _findNearestGraphNodeCandidates(graph, from);
    final endCandidates = _findNearestGraphNodeCandidates(graph, to);
    if (startCandidates.isEmpty || endCandidates.isEmpty) {
      return null;
    }

    _ShortestPathResult? bestPath;
    _GraphNodeDistance? bestStart;
    _GraphNodeDistance? bestEnd;
    double? bestTotalDistance;

    for (final start in startCandidates.take(5)) {
      for (final end in endCandidates.take(5)) {
        final aStarPath = _runAStar(graph, start.nodeId, end.nodeId);
        final dijkstraPath = _runDijkstra(graph, start.nodeId, end.nodeId);
        final chosenPath = _chooseBestPath(aStarPath, dijkstraPath);
        if (chosenPath == null || chosenPath.nodeIds.isEmpty) {
          continue;
        }

        final totalDistance = chosenPath.distanceMeters +
            start.distanceMeters +
            end.distanceMeters;
        if (bestTotalDistance == null || totalDistance < bestTotalDistance) {
          bestTotalDistance = totalDistance;
          bestPath = chosenPath;
          bestStart = start;
          bestEnd = end;
        }
      }
    }

    if (bestPath == null || bestStart == null || bestEnd == null) {
      return null;
    }

    final points = <latlng.LatLng>[from];
    for (final nodeId in bestPath.nodeIds) {
      final point = graph.nodes[nodeId];
      if (point != null) {
        points.add(point);
      }
    }
    if (points.last.latitude != to.latitude ||
        points.last.longitude != to.longitude) {
      points.add(to);
    }

    final distanceMeters = bestPath.distanceMeters +
        bestStart.distanceMeters +
        bestEnd.distanceMeters;
    final durationSeconds = distanceMeters / _walkingSpeedMetersPerSecond;

    return _RouteInfo(
      points: points,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
    );
  }

  Future<_WalkingGraph> _buildWalkingGraph({
    required latlng.LatLng origin,
    required List<latlng.LatLng> destinations,
    double paddingDegrees = 0.01,
  }) async {
    final points = [origin, ...destinations];
    final latitudes = points.map((point) => point.latitude);
    final longitudes = points.map((point) => point.longitude);
    final centerLatitude =
        points.map((point) => point.latitude).reduce((a, b) => a + b) /
            points.length;
    final latitudePadding = paddingDegrees;
    final longitudePadding = paddingDegrees /
        (math.cos(centerLatitude * math.pi / 180).abs().clamp(0.3, 1.0));

    final south = latitudes.reduce((a, b) => a < b ? a : b) - latitudePadding;
    final north = latitudes.reduce((a, b) => a > b ? a : b) + latitudePadding;
    final west = longitudes.reduce((a, b) => a < b ? a : b) - longitudePadding;
    final east = longitudes.reduce((a, b) => a > b ? a : b) + longitudePadding;

    final query = '''
[out:json][timeout:25];
(
  way["highway"]($south,$west,$north,$east);
);
(._;>;);
out body;
''';
    final uri =
        Uri.https('overpass-api.de', '/api/interpreter', {'data': query});
    final response = await http.get(uri, headers: {
      'User-Agent': 'Protego/1.0 (safety app)',
      'Accept': 'application/json',
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const _WalkingGraph(nodes: {}, adjacency: {});
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return const _WalkingGraph(nodes: {}, adjacency: {});
    }

    final elements = decoded['elements'];
    if (elements is! List) {
      return const _WalkingGraph(nodes: {}, adjacency: {});
    }

    final nodes = <int, latlng.LatLng>{};
    final ways = <Map<String, dynamic>>[];
    for (final element in elements) {
      if (element is! Map<String, dynamic>) continue;
      if (element['type'] == 'node') {
        final id = element['id'] as num?;
        final lat = element['lat'] as num?;
        final lon = element['lon'] as num?;
        if (id == null || lat == null || lon == null) continue;
        nodes[id.toInt()] = latlng.LatLng(lat.toDouble(), lon.toDouble());
      } else if (element['type'] == 'way') {
        ways.add(element);
      }
    }

    final adjacency = <int, List<_GraphEdge>>{};
    for (final way in ways) {
      final tags = way['tags'];
      if (!_isWalkableWay(tags is Map<String, dynamic> ? tags : const {})) {
        continue;
      }
      final nodeRefs = way['nodes'];
      if (nodeRefs is! List || nodeRefs.length < 2) continue;

      final walkForward =
          !_isOneWayFootBlocked(tags is Map<String, dynamic> ? tags : const {});
      for (var i = 0; i < nodeRefs.length - 1; i++) {
        final fromId = (nodeRefs[i] as num?)?.toInt();
        final toId = (nodeRefs[i + 1] as num?)?.toInt();
        if (fromId == null || toId == null) continue;
        final fromPoint = nodes[fromId];
        final toPoint = nodes[toId];
        if (fromPoint == null || toPoint == null) continue;

        final distance = Geolocator.distanceBetween(
          fromPoint.latitude,
          fromPoint.longitude,
          toPoint.latitude,
          toPoint.longitude,
        );
        adjacency.putIfAbsent(fromId, () => []).add(
              _GraphEdge(toNodeId: toId, distanceMeters: distance),
            );
        if (walkForward) {
          adjacency.putIfAbsent(toId, () => []).add(
                _GraphEdge(toNodeId: fromId, distanceMeters: distance),
              );
        }
      }
    }

    return _WalkingGraph(nodes: nodes, adjacency: adjacency);
  }

  bool _isWalkableWay(Map<String, dynamic> tags) {
    const blockedHighways = {
      'motorway',
      'motorway_link',
      'trunk',
      'trunk_link',
      'construction',
      'raceway',
    };
    final highway = tags['highway'] as String?;
    if (highway == null || blockedHighways.contains(highway)) {
      return false;
    }

    final access = tags['access'] as String?;
    final foot = tags['foot'] as String?;
    if (access == 'private' || access == 'no' || foot == 'no') {
      return false;
    }

    return true;
  }

  bool _isOneWayFootBlocked(Map<String, dynamic> tags) {
    final oneWayFoot = tags['oneway:foot'] as String?;
    if (oneWayFoot == 'yes') {
      return false;
    }
    return (tags['oneway'] as String?) != 'yes';
  }

  List<_GraphNodeDistance> _findNearestGraphNodeCandidates(
    _WalkingGraph graph,
    latlng.LatLng point,
  ) {
    final candidates = <_GraphNodeDistance>[];

    graph.nodes.forEach((nodeId, nodePoint) {
      if (!(graph.adjacency[nodeId]?.isNotEmpty ?? false)) {
        return;
      }
      final distance = Geolocator.distanceBetween(
        point.latitude,
        point.longitude,
        nodePoint.latitude,
        nodePoint.longitude,
      );
      candidates.add(
        _GraphNodeDistance(nodeId: nodeId, distanceMeters: distance),
      );
    });

    candidates.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return candidates.take(12).toList();
  }

  _ShortestPathResult? _chooseBestPath(
    _ShortestPathResult? aStarPath,
    _ShortestPathResult? dijkstraPath,
  ) {
    if (aStarPath == null) return dijkstraPath;
    if (dijkstraPath == null) return aStarPath;
    return aStarPath.distanceMeters <= dijkstraPath.distanceMeters
        ? aStarPath
        : dijkstraPath;
  }

  _ShortestPathResult? _runAStar(
    _WalkingGraph graph,
    int startNodeId,
    int endNodeId,
  ) {
    final openSet =
        _MinHeap<_FrontierNode>((a, b) => a.priority.compareTo(b.priority))
          ..add(_FrontierNode(nodeId: startNodeId, priority: 0));
    final cameFrom = <int, int>{};
    final gScore = <int, double>{startNodeId: 0};
    final fScore = <int, double>{
      startNodeId: _heuristicDistance(graph, startNodeId, endNodeId),
    };
    final closedSet = <int>{};

    while (openSet.isNotEmpty) {
      final current = openSet.removeFirst().nodeId;
      if (!closedSet.add(current)) {
        continue;
      }
      if (current == endNodeId) {
        return _reconstructPath(cameFrom, current, gScore[current] ?? 0);
      }

      for (final edge in graph.adjacency[current] ?? const <_GraphEdge>[]) {
        final tentative =
            (gScore[current] ?? double.infinity) + edge.distanceMeters;
        if (tentative >= (gScore[edge.toNodeId] ?? double.infinity)) {
          continue;
        }
        cameFrom[edge.toNodeId] = current;
        gScore[edge.toNodeId] = tentative;
        final estimatedTotal =
            tentative + _heuristicDistance(graph, edge.toNodeId, endNodeId);
        fScore[edge.toNodeId] = estimatedTotal;
        if (!closedSet.contains(edge.toNodeId)) {
          openSet.add(
            _FrontierNode(nodeId: edge.toNodeId, priority: estimatedTotal),
          );
        }
      }
    }

    return null;
  }

  _ShortestPathResult? _runDijkstra(
    _WalkingGraph graph,
    int startNodeId,
    int endNodeId,
  ) {
    final queue =
        _MinHeap<_FrontierNode>((a, b) => a.priority.compareTo(b.priority))
          ..add(_FrontierNode(nodeId: startNodeId, priority: 0));
    final distances = <int, double>{startNodeId: 0};
    final cameFrom = <int, int>{};
    final visited = <int>{};

    while (queue.isNotEmpty) {
      final current = queue.removeFirst().nodeId;
      if (!visited.add(current)) {
        continue;
      }
      if (current == endNodeId) {
        return _reconstructPath(cameFrom, current, distances[current] ?? 0);
      }

      for (final edge in graph.adjacency[current] ?? const <_GraphEdge>[]) {
        final tentative =
            (distances[current] ?? double.infinity) + edge.distanceMeters;
        if (tentative >= (distances[edge.toNodeId] ?? double.infinity)) {
          continue;
        }
        distances[edge.toNodeId] = tentative;
        cameFrom[edge.toNodeId] = current;
        queue.add(_FrontierNode(nodeId: edge.toNodeId, priority: tentative));
      }
    }

    return null;
  }

  double _heuristicDistance(_WalkingGraph graph, int fromNodeId, int toNodeId) {
    final from = graph.nodes[fromNodeId];
    final to = graph.nodes[toNodeId];
    if (from == null || to == null) {
      return 0;
    }
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  _ShortestPathResult _reconstructPath(
    Map<int, int> cameFrom,
    int current,
    double distanceMeters,
  ) {
    final path = <int>[current];
    while (cameFrom.containsKey(current)) {
      current = cameFrom[current]!;
      path.add(current);
    }
    return _ShortestPathResult(
      nodeIds: path.reversed.toList(),
      distanceMeters: distanceMeters,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
              const SizedBox(height: 12),
              if (widget.isSosActive) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.red.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mic, color: Colors.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'SOS is active. Voice recording is running and stored locally.',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onStopSos,
                        child: const Text('Stop SOS'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 520,
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildMapContent(theme, isDark)),
                      if (!_isLoading && _position != null)
                        Positioned.fill(child: _buildMapOverlay(theme, isDark)),
                    ],
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _initLocationTracking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Retry Location Access',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapContent(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return ColoredBox(
        color: isDark ? const Color(0xFF101010) : const Color(0xFFF8FAFC),
        child: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    if (_position == null) {
      return ColoredBox(
        color: isDark ? const Color(0xFF101010) : const Color(0xFFF8FAFC),
        child: Center(
          child: Text(
            'Location unavailable',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
      );
    }

    final current = latlng.LatLng(_position!.latitude, _position!.longitude);
    final destination = _nearestPoliceStation;
    final routePoints = _routePoints.length >= 2
        ? _routePoints
        : (destination != null
            ? [current, destination]
            : const <latlng.LatLng>[]);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: current,
        initialZoom: 16,
        maxZoom: 19,
        minZoom: 3,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.protego',
          retinaMode: RetinaMode.isHighDensity(context),
          maxNativeZoom: 19,
        ),
        if (routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                color: theme.colorScheme.primary.withValues(alpha: 0.9),
                strokeWidth: 6,
              ),
            ],
          ),
        CircleLayer(
          circles: [
            CircleMarker(
              point: current,
              radius: _position!.accuracy.clamp(20, 120).toDouble() / 2,
              color: theme.colorScheme.primary.withValues(alpha: 0.16),
              borderColor: theme.colorScheme.primary.withValues(alpha: 0.55),
              borderStrokeWidth: 1,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: current,
              width: 28,
              height: 28,
              child: Icon(
                Icons.my_location,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            if (destination != null)
              Marker(
                point: destination,
                width: 36,
                height: 36,
                child: const Icon(
                  Icons.local_police,
                  color: Color(0xFFFF4D4F),
                  size: 30,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMapOverlay(ThemeData theme, bool isDark) {
    final distanceText = _routeDistanceKm == null
        ? '--'
        : '${_routeDistanceKm!.toStringAsFixed(_routeDistanceKm! < 10 ? 1 : 0)} km';
    final etaText =
        _routeEtaMinutes == null ? '--' : '${_routeEtaMinutes!.round()} min';

    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: isDark ? 0.62 : 0.7),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_police,
                          color: Color(0xFFFFD54F), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Police Walk Route',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: isDark ? 0.62 : 0.7),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Text(
                    'GPS ${_position!.accuracy.toStringAsFixed(0)}m',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: isDark ? 0.7 : 0.82),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.route, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nearestPoliceStationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _nearestPoliceStation == null
                              ? 'Finding nearest police station...'
                              : 'Shortest walking path using A* + Dijkstra',
                          style: const TextStyle(
                            color: Color(0xFFD1D5DB),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: isDark ? 0.68 : 0.78),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.14)),
                ),
                child: Text(
                  'Walk: $distanceText   ETA: $etaText',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PoliceStation {
  const _PoliceStation({required this.name, required this.position});

  final String name;
  final latlng.LatLng position;
}

class _PoliceStationDistance {
  const _PoliceStationDistance({
    required this.station,
    required this.straightLineDistance,
  });

  final _PoliceStation station;
  final double straightLineDistance;
}

class _GraphNodeDistance {
  const _GraphNodeDistance({
    required this.nodeId,
    required this.distanceMeters,
  });

  final int nodeId;
  final double distanceMeters;
}

class _RouteInfo {
  const _RouteInfo({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<latlng.LatLng> points;
  final double? distanceMeters;
  final double? durationSeconds;
}

class _WalkingGraph {
  const _WalkingGraph({required this.nodes, required this.adjacency});

  final Map<int, latlng.LatLng> nodes;
  final Map<int, List<_GraphEdge>> adjacency;
}

class _FrontierNode {
  const _FrontierNode({required this.nodeId, required this.priority});

  final int nodeId;
  final double priority;
}

class _MinHeap<T> {
  _MinHeap(this._compare);

  final int Function(T a, T b) _compare;
  final List<T> _items = <T>[];

  bool get isNotEmpty => _items.isNotEmpty;

  void add(T value) {
    _items.add(value);
    _siftUp(_items.length - 1);
  }

  T removeFirst() {
    final first = _items.first;
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      _siftDown(0);
    }
    return first;
  }

  void _siftUp(int index) {
    var child = index;
    while (child > 0) {
      final parent = (child - 1) ~/ 2;
      if (_compare(_items[child], _items[parent]) >= 0) {
        break;
      }
      _swap(child, parent);
      child = parent;
    }
  }

  void _siftDown(int index) {
    var parent = index;
    while (true) {
      final left = (parent * 2) + 1;
      final right = left + 1;
      var candidate = parent;

      if (left < _items.length &&
          _compare(_items[left], _items[candidate]) < 0) {
        candidate = left;
      }
      if (right < _items.length &&
          _compare(_items[right], _items[candidate]) < 0) {
        candidate = right;
      }
      if (candidate == parent) {
        break;
      }

      _swap(parent, candidate);
      parent = candidate;
    }
  }

  void _swap(int left, int right) {
    final temp = _items[left];
    _items[left] = _items[right];
    _items[right] = temp;
  }
}

class _GraphEdge {
  const _GraphEdge({required this.toNodeId, required this.distanceMeters});

  final int toNodeId;
  final double distanceMeters;
}

class _ShortestPathResult {
  const _ShortestPathResult({
    required this.nodeIds,
    required this.distanceMeters,
  });

  final List<int> nodeIds;
  final double distanceMeters;
}

class _EmergencyContactsTab extends StatefulWidget {
  const _EmergencyContactsTab();

  @override
  State<_EmergencyContactsTab> createState() => _EmergencyContactsTabState();
}

class _EmergencyContactsTabState extends State<_EmergencyContactsTab> {
  final _service = EmergencyContactsService();
  bool _isLoading = true;
  List<EmergencyContact> _contacts = const [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await _service.getContacts();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _isLoading = false;
    });
  }

  Future<void> _openContactSheet({EmergencyContact? contact}) async {
    final didSave = await showEmergencyContactEditorSheet(
      context,
      contact: contact,
      suggestPrimary: _contacts.isEmpty,
      onSave: _service.saveContact,
    );
    if (!mounted || !didSave) return;
    await _loadContacts();
  }

  Future<void> _callContact(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not place the call.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency Contacts',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Keep trusted people ready for one-tap access.',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFA3A3A3)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _openContactSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _contacts.isEmpty
                      ? 'Add at least one trusted person so you can reach them quickly in an emergency.'
                      : 'Tap any card below to call, edit, or remove a saved contact.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_contacts.isEmpty)
          _SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No contacts saved yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add trusted contacts so you can call them quickly during emergencies.',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFA3A3A3)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          )
        else
          ..._contacts.map(
            (contact) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StoredEmergencyContactTile(
                contact: contact,
                onCall: () => _callContact(contact.phoneNumber),
                onEdit: () => _openContactSheet(contact: contact),
                onDelete: () async {
                  await _service.deleteContact(contact.id!);
                  await _loadContacts();
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _StoredEmergencyContactTile extends StatelessWidget {
  const _StoredEmergencyContactTile({
    required this.contact,
    required this.onCall,
    required this.onEdit,
    required this.onDelete,
  });

  final EmergencyContact contact;
  final VoidCallback onCall;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  contact.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (contact.isPrimary)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Primary',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.phone_iphone, size: 18),
              const SizedBox(width: 8),
              Text(
                contact.phoneNumber,
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCall,
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
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
    final isDark = theme.brightness == Brightness.dark;
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
        const SizedBox(height: 14),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.library_music_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SOS recordings',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Open the locally stored emergency audio files and review their saved file paths.',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFA3A3A3)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SosRecordingsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.playlist_play),
                  label: const Text('View SOS Recordings'),
                ),
              ),
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
