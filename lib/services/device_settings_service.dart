import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceSettingsService {
  const DeviceSettingsService._();

  static Future<bool> openSystemAppSettings() {
    return openAppSettings();
  }

  static Future<bool> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) {
      return openAppSettings();
    }

    try {
      await const AndroidIntent(
        action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
      ).launch();
      return true;
    } catch (_) {
      return openAppSettings();
    }
  }
}
