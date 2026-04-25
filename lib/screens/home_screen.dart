import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

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
          _HomeTab(
            user: user,
            onSosActivated: () {
              setState(() => _currentIndex = 1);
            },
          ),
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
  const _HomeTab({
    required this.user,
    required this.onSosActivated,
  });

  final User? user;
  final VoidCallback onSosActivated;

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
        _SosHoldButton(onActivated: onSosActivated),
      ],
    );
  }
}

class _SosHoldButton extends StatefulWidget {
  const _SosHoldButton({required this.onActivated});

  final VoidCallback onActivated;

  @override
  State<_SosHoldButton> createState() => _SosHoldButtonState();
}

class _SosHoldButtonState extends State<_SosHoldButton>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _holdController;
  bool _isHolding = false;
  bool _activated = false;

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
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Emergency activated. Help is on the way!',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.red,
            ),
          );
          widget.onActivated();
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
    if (_isHolding) return;
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
            'Press and hold for 2 seconds to trigger emergency assistance.',
            style: TextStyle(
              color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: GestureDetector(
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
                            color: Colors.red
                                .withValues(alpha: _isHolding ? 0.25 : 0.18),
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
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.red),
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
              _isHolding
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
  const _LiveMapTab();

  @override
  State<_LiveMapTab> createState() => _LiveMapTabState();
}

class _LiveMapTabState extends State<_LiveMapTab> with WidgetsBindingObserver {
  static const String _googleDarkMapStyle = '''
  [
    {"elementType":"geometry","stylers":[{"color":"#0f0f0f"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#9ca3af"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#0b0b0b"}]},
    {"featureType":"poi","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1a1a1a"}]},
    {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#222222"}]},
    {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2c2c2c"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#101826"}]}
  ]
  ''';

  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSubscription;
  Position? _position;
  LatLng? _nearestPoliceStation;
  LatLng? _lastRouteFetchOrigin;
  String _nearestPoliceStationName = 'Nearest police station';
  List<LatLng> _routePoints = const [];
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

  Future<void> _moveCameraTo(LatLng target, {double? zoom}) async {
    final controller = _mapController;
    if (controller == null) return;
    final update = zoom == null
        ? CameraUpdate.newLatLng(target)
        : CameraUpdate.newCameraPosition(
            CameraPosition(target: target, zoom: zoom),
          );
    await controller.animateCamera(update);
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
        _moveCameraTo(LatLng(cached.latitude, cached.longitude), zoom: 15.5);
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
      _moveCameraTo(LatLng(current.latitude, current.longitude), zoom: 16);
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
        _moveCameraTo(LatLng(position.latitude, position.longitude));
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
    _lastRouteFetchOrigin = LatLng(position.latitude, position.longitude);
    try {
      final station = await _findNearestPoliceStation(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (station == null) {
        if (!mounted || _nearestPoliceStation != null) return;
        setState(() {
          _nearestPoliceStationName = 'No nearby police station found';
          _routePoints = const [];
          _routeDistanceKm = null;
          _routeEtaMinutes = null;
        });
        return;
      }

      final route = await _buildRouteToPoliceStation(
        from: LatLng(position.latitude, position.longitude),
        to: station.position,
      );

      if (!mounted) return;
      final distanceMeters = route?.distanceMeters;
      final durationSeconds = route?.durationSeconds;
      setState(() {
        _nearestPoliceStation = station.position;
        _nearestPoliceStationName = station.name;
        _routePoints = route?.points ??
            [
              LatLng(position.latitude, position.longitude),
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

  Future<_PoliceStation?> _findNearestPoliceStation({
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
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final elements = decoded['elements'];
    if (elements is! List || elements.isEmpty) {
      return null;
    }

    Map<String, dynamic>? closest;
    double? closestDistance;
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

      final distance =
          Geolocator.distanceBetween(latitude, longitude, lat, lon);
      if (closestDistance == null || distance < closestDistance) {
        closestDistance = distance;
        closest = item;
      }
    }

    if (closest == null) {
      return null;
    }

    final tags = closest['tags'];
    final lat = (closest['lat'] as num?)?.toDouble() ??
        (closest['center'] is Map<String, dynamic>
            ? ((closest['center']['lat'] as num?)?.toDouble())
            : null);
    final lon = (closest['lon'] as num?)?.toDouble() ??
        (closest['center'] is Map<String, dynamic>
            ? ((closest['center']['lon'] as num?)?.toDouble())
            : null);
    if (lat == null || lon == null) {
      return null;
    }

    final name = tags is Map<String, dynamic>
        ? (tags['name'] as String?) ?? 'Nearest police station'
        : 'Nearest police station';

    return _PoliceStation(
      name: name,
      position: LatLng(lat, lon),
    );
  }

  Future<_RouteInfo?> _buildRouteToPoliceStation({
    required LatLng from,
    required LatLng to,
  }) async {
    final coordinates =
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
    final uri =
        Uri.https('router.project-osrm.org', '/route/v1/driving/$coordinates', {
      'overview': 'full',
      'geometries': 'geojson',
    });
    final response = await http.get(uri, headers: {
      'User-Agent': 'Protego/1.0 (safety app)',
      'Accept': 'application/json',
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final routes = decoded['routes'];
    if (routes is! List ||
        routes.isEmpty ||
        routes.first is! Map<String, dynamic>) {
      return null;
    }

    final firstRoute = routes.first as Map<String, dynamic>;
    final distanceMeters = (firstRoute['distance'] as num?)?.toDouble();
    final durationSeconds = (firstRoute['duration'] as num?)?.toDouble();

    final geometry = firstRoute['geometry'];
    final coordinatesList =
        geometry is Map<String, dynamic> ? geometry['coordinates'] : null;

    final points = <LatLng>[];
    if (coordinatesList is List) {
      for (final coordinate in coordinatesList) {
        if (coordinate is! List || coordinate.length < 2) continue;
        final lon = (coordinate[0] as num?)?.toDouble();
        final lat = (coordinate[1] as num?)?.toDouble();
        if (lat == null || lon == null) continue;
        points.add(LatLng(lat, lon));
      }
    }

    return _RouteInfo(
      points: points,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
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

    final current = LatLng(_position!.latitude, _position!.longitude);
    final destination = _nearestPoliceStation;
    final routePoints = _routePoints.length >= 2
        ? _routePoints
        : (destination != null ? [current, destination] : const <LatLng>[]);

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('current_location'),
        position: current,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ),
      if (destination != null)
        Marker(
          markerId: const MarkerId('nearest_police_station'),
          position: destination,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: _nearestPoliceStationName),
        ),
    };

    final circles = <Circle>{
      Circle(
        circleId: const CircleId('accuracy'),
        center: current,
        radius: _position!.accuracy.clamp(20, 120).toDouble(),
        fillColor: theme.colorScheme.primary.withValues(alpha: 0.16),
        strokeColor: theme.colorScheme.primary.withValues(alpha: 0.55),
        strokeWidth: 1,
      ),
    };

    final polylines = <Polyline>{
      if (routePoints.length >= 2)
        Polyline(
          polylineId: const PolylineId('route_to_police'),
          points: routePoints,
          color: theme.colorScheme.primary.withValues(alpha: 0.9),
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
    };

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: current, zoom: 16),
      style: isDark ? _googleDarkMapStyle : null,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: true,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      mapType: MapType.normal,
      markers: markers,
      circles: circles,
      polylines: polylines,
      onMapCreated: (controller) {
        _mapController = controller;
        _moveCameraTo(current, zoom: 16);
      },
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
                        'Police Route',
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
                              : 'Direction ready from your live location',
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
                  'Distance: $distanceText   ETA: $etaText',
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
  final LatLng position;
}

class _RouteInfo {
  const _RouteInfo({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double? distanceMeters;
  final double? durationSeconds;
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
