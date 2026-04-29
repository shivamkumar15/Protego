import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPermissionsScreen extends StatefulWidget {
  const AppPermissionsScreen({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  static const permissionsPrefsKey = 'app_permissions_completed_v1';

  @override
  State<AppPermissionsScreen> createState() => _AppPermissionsScreenState();
}

class _AppPermissionsScreenState extends State<AppPermissionsScreen>
    with WidgetsBindingObserver {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isChecking = true;
  bool _isSubmitting = false;
  bool _locationGranted = false;
  bool _micGranted = false;
  bool _locationServiceEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissionState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recorder.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissionState();
    }
  }

  Future<void> _refreshPermissionState() async {
    final locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    final locationPermission = await Geolocator.checkPermission();
    final micGranted = await _safeMicPermissionCheck();

    if (!mounted) {
      return;
    }

    setState(() {
      _locationServiceEnabled = locationServiceEnabled;
      _locationGranted = locationPermission == LocationPermission.always ||
          locationPermission == LocationPermission.whileInUse;
      _micGranted = micGranted;
      _isChecking = false;
    });

    if (_locationServiceEnabled && _locationGranted && _micGranted) {
      await _markComplete();
    }
  }

  Future<void> _markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppPermissionsScreen.permissionsPrefsKey, true);
    if (mounted) {
      widget.onCompleted();
    }
  }

  Future<void> _requestAllPermissions() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      var serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
      }

      var locationPermission = await Geolocator.checkPermission();
      if (locationPermission == LocationPermission.denied) {
        locationPermission = await Geolocator.requestPermission();
      }
      if (locationPermission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      }

      final micGranted = await _safeMicPermissionCheck();
      if (!micGranted) {
        await Geolocator.openAppSettings();
      }

      await _refreshPermissionState();

      if (!mounted) {
        return;
      }

      final allGranted =
          _locationServiceEnabled && _locationGranted && _micGranted;
      if (!allGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please allow location, microphone, and keep location services on to continue.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<bool> _safeMicPermissionCheck() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: _isChecking
              ? Center(
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 34,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Enable core permissions',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Aegixa needs location and microphone access from the start so SOS, live tracking, and emergency evidence work instantly.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: isDark
                            ? const Color(0xFFA3A3A3)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 26),
                    _PermissionStatusTile(
                      icon: Icons.location_on_outlined,
                      title: 'Location access',
                      subtitle: _locationServiceEnabled
                          ? 'Required for live route and nearby police navigation.'
                          : 'Turn on device location services to continue.',
                      isGranted: _locationGranted && _locationServiceEnabled,
                    ),
                    const SizedBox(height: 12),
                    _PermissionStatusTile(
                      icon: Icons.mic_none_rounded,
                      title: 'Microphone access',
                      subtitle:
                          'Required to record audio automatically during SOS.',
                      isGranted: _micGranted,
                    ),
                    const Spacer(),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF101010)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Text(
                        'You only need to do this once after installation. If you deny a permission permanently, Aegixa will open app settings so you can enable it.',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFA3A3A3)
                              : const Color(0xFF6B7280),
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed:
                            _isSubmitting ? null : _requestAllPermissions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Allow Permissions',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PermissionStatusTile extends StatelessWidget {
  const _PermissionStatusTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isGranted,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isGranted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isGranted
                  ? const Color(0xFFDCFCE7)
                  : theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isGranted ? Icons.check_rounded : icon,
              color: isGranted
                  ? const Color(0xFF15803D)
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFA3A3A3)
                        : const Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
