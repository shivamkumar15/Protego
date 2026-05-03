import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'emergency_contacts_service.dart';
import 'username_service.dart';

class SosAlert {
  const SosAlert({
    required this.id,
    required this.sessionId,
    required this.senderUserId,
    required this.senderName,
    this.senderUsername,
    this.senderPhoneNumber,
    this.senderPhotoPath,
    required this.recipientUserId,
    this.recipientUsername,
    required this.contactName,
    required this.contactPhoneNumber,
    required this.isPrimary,
    required this.alertMessage,
    required this.latitude,
    required this.longitude,
    this.locationAccuracyMeters,
    required this.status,
    this.voiceRecordingUrl,
    this.videoRecordingUrl,
    required this.triggeredAt,
    required this.updatedAt,
    this.resolvedAt,
  });

  final int id;
  final String sessionId;
  final String senderUserId;
  final String senderName;
  final String? senderUsername;
  final String? senderPhoneNumber;
  final String? senderPhotoPath;
  final String recipientUserId;
  final String? recipientUsername;
  final String contactName;
  final String contactPhoneNumber;
  final bool isPrimary;
  final String alertMessage;
  final double latitude;
  final double longitude;
  final double? locationAccuracyMeters;
  final String status;
  final String? voiceRecordingUrl;
  final String? videoRecordingUrl;
  final DateTime triggeredAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;

  factory SosAlert.fromMap(Map<String, dynamic> map) {
    double? parseDouble(Object? value) {
      if (value is num) return value.toDouble();
      return double.tryParse((value ?? '').toString());
    }

    return SosAlert(
      id: (map['id'] as num).toInt(),
      sessionId: (map['session_id'] ?? '').toString(),
      senderUserId: (map['sender_user_id'] ?? '').toString(),
      senderName: (map['sender_name'] ?? '').toString(),
      senderUsername: map['sender_username'] as String?,
      senderPhoneNumber: map['sender_phone_number'] as String?,
      senderPhotoPath: map['sender_photo_path'] as String?,
      recipientUserId: (map['recipient_user_id'] ?? '').toString(),
      recipientUsername: map['recipient_username'] as String?,
      contactName: (map['contact_name'] ?? '').toString(),
      contactPhoneNumber: (map['contact_phone_number'] ?? '').toString(),
      isPrimary: map['is_primary'] == true,
      alertMessage: (map['alert_message'] ?? '').toString(),
      latitude: parseDouble(map['latitude']) ?? 0,
      longitude: parseDouble(map['longitude']) ?? 0,
      locationAccuracyMeters: parseDouble(map['location_accuracy_meters']),
      status: (map['status'] ?? 'active').toString(),
      voiceRecordingUrl: map['voice_recording_url'] as String?,
      videoRecordingUrl: map['video_recording_url'] as String?,
      triggeredAt: DateTime.parse((map['triggered_at'] ?? '').toString()),
      updatedAt: DateTime.parse((map['updated_at'] ?? '').toString()),
      resolvedAt: map['resolved_at'] == null
          ? null
          : DateTime.parse(map['resolved_at'].toString()),
    );
  }
}

class SosAlertDispatchSummary {
  const SosAlertDispatchSummary({
    required this.sessionId,
    required this.deliveredCount,
    required this.skippedCount,
    required this.hasPrimaryRecipient,
    required this.pushDeliveredCount,
    required this.pushSkippedCount,
    this.pushErrorMessage,
  });

  final String sessionId;
  final int deliveredCount;
  final int skippedCount;
  final bool hasPrimaryRecipient;
  final int pushDeliveredCount;
  final int pushSkippedCount;
  final String? pushErrorMessage;
}

class _PushDispatchSummary {
  const _PushDispatchSummary({
    required this.deliveredCount,
    required this.skippedCount,
    this.errorMessage,
  });

  final int deliveredCount;
  final int skippedCount;
  final String? errorMessage;
}

class SosAlertService {
  SosAlertService._();

  static final SosAlertService _instance = SosAlertService._();
  factory SosAlertService() => _instance;

  static const _table = 'sos_alerts';
  static const _recordingsBucket = 'sos-alert-recordings';
  static const _downloadedVoiceRecordingsKey =
      'downloaded_sos_voice_recordings_v1';
  static const _downloadedVideoRecordingsKey =
      'downloaded_sos_video_recordings_v1';

  final SupabaseClient _supabase = Supabase.instance.client;
  final UsernameService _usernameService = UsernameService();

  String get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('User must be signed in to send SOS alerts.');
    }
    return user.uid;
  }

  Future<SosAlertDispatchSummary> triggerAlerts({
    required List<EmergencyContact> contacts,
    required Position position,
    required String alertMessage,
  }) async {
    try {
      final currentUserId = _currentUserId;
      final senderProfile =
          await _usernameService.getPublicProfileForUserId(currentUserId);
      final senderName = _resolveSenderName(senderProfile);
      final sessionId =
          '${currentUserId}_${DateTime.now().millisecondsSinceEpoch}';

      final usernames = contacts
          .map((contact) => (contact.username ?? '').trim())
          .where((username) => username.isNotEmpty)
          .toSet()
          .toList();

      if (usernames.isEmpty) {
        throw StateError(
          'No emergency contacts are linked to Aegixa accounts yet. Add contacts with usernames to use in-app SOS alerts.',
        );
      }

      final profileRows = await _supabase
          .from('public_profiles')
          .select('uid,username')
          .inFilter('username', usernames);

      final profileByUsername = <String, Map<String, dynamic>>{};
      for (final row in profileRows.whereType<Map<String, dynamic>>()) {
        final username = (row['username'] ?? '').toString().trim();
        if (username.isNotEmpty) {
          profileByUsername[username] = row;
        }
      }

      final rows = <Map<String, Object?>>[];
      var deliveredCount = 0;
      var skippedCount = 0;
      var hasPrimaryRecipient = false;

      for (final contact in contacts) {
        final username = (contact.username ?? '').trim();
        final profile = profileByUsername[username];
        final recipientUserId = (profile?['uid'] ?? '').toString().trim();
        if (username.isEmpty ||
            recipientUserId.isEmpty ||
            recipientUserId == currentUserId) {
          skippedCount++;
          continue;
        }

        rows.add({
          'session_id': sessionId,
          'sender_user_id': currentUserId,
          'sender_name': senderName,
          'sender_username': senderProfile?.username,
          'sender_phone_number': senderProfile?.phoneNumber,
          'sender_photo_path': senderProfile?.profilePhotoPath,
          'recipient_user_id': recipientUserId,
          'recipient_username': username,
          'contact_name': contact.name,
          'contact_phone_number': contact.phoneNumber,
          'is_primary': contact.isPrimary,
          'alert_message': alertMessage,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'location_accuracy_meters': position.accuracy,
        });
        deliveredCount++;
        if (contact.isPrimary) {
          hasPrimaryRecipient = true;
        }
      }

      if (rows.isEmpty) {
        throw StateError(
          'None of your saved emergency contacts can receive in-app SOS alerts yet. Ask them to join Aegixa and save their username in your contact list.',
        );
      }

      final insertedRows = await _supabase
          .from(_table)
          .insert(rows)
          .select('id,session_id,recipient_user_id,sender_name,alert_message');

      final pushSummary = await _dispatchPushAlerts(insertedRows);

      return SosAlertDispatchSummary(
        sessionId: sessionId,
        deliveredCount: deliveredCount,
        skippedCount: skippedCount,
        hasPrimaryRecipient: hasPrimaryRecipient,
        pushDeliveredCount: pushSummary.deliveredCount,
        pushSkippedCount: pushSummary.skippedCount,
        pushErrorMessage: pushSummary.errorMessage,
      );
    } on PostgrestException catch (error) {
      throw StateError(_friendlySupabaseError(error));
    } on StorageException catch (error) {
      throw StateError(_friendlyStorageError(error));
    }
  }

  Future<void> updateLiveLocation({
    required String sessionId,
    required Position position,
  }) async {
    try {
      await _supabase
          .from(_table)
          .update({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'location_accuracy_meters': position.accuracy,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('session_id', sessionId)
          .eq('sender_user_id', _currentUserId)
          .eq('status', 'active');
    } on PostgrestException catch (error) {
      throw StateError(_friendlySupabaseError(error));
    }
  }

  Future<void> resolveAlertSession({
    required String sessionId,
    String? voiceRecordingPath,
    String? videoRecordingPath,
  }) async {
    try {
      String? uploadedVoiceUrl;
      String? uploadedVideoUrl;
      if ((voiceRecordingPath ?? '').trim().isNotEmpty) {
        uploadedVoiceUrl = await _uploadMediaRecording(
          sessionId: sessionId,
          localFilePath: voiceRecordingPath!.trim(),
          fileStem: 'voice_recording',
        );
      }
      if ((videoRecordingPath ?? '').trim().isNotEmpty) {
        uploadedVideoUrl = await _uploadMediaRecording(
          sessionId: sessionId,
          localFilePath: videoRecordingPath!.trim(),
          fileStem: 'video_recording',
        );
      }

      if (uploadedVoiceUrl != null || uploadedVideoUrl != null) {
        await _supabase
            .from(_table)
            .update({
              if (uploadedVoiceUrl != null)
                'voice_recording_url': uploadedVoiceUrl,
              if (uploadedVideoUrl != null)
                'video_recording_url': uploadedVideoUrl,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('session_id', sessionId)
            .eq('sender_user_id', _currentUserId);
      }

      await _supabase
          .from(_table)
          .update({
            'status': 'resolved',
            'resolved_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('session_id', sessionId)
          .eq('sender_user_id', _currentUserId);
    } on PostgrestException catch (error) {
      throw StateError(_friendlySupabaseError(error));
    } on StorageException catch (error) {
      throw StateError(_friendlyStorageError(error));
    }
  }

  Stream<List<SosAlert>> watchReceivedAlerts() {
    return _supabase
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('recipient_user_id', _currentUserId)
        .map(
          (rows) => rows
              .whereType<Map<String, dynamic>>()
              .map(SosAlert.fromMap)
              .toList()
            ..sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt)),
        );
  }

  Future<String?> getDownloadedVoiceRecordingPath(int alertId) async {
    final savedPaths = await _loadDownloadedMediaPaths(
      _downloadedVoiceRecordingsKey,
    );
    final filePath = savedPaths['$alertId'];
    if ((filePath ?? '').trim().isEmpty) {
      return null;
    }

    final file = File(filePath!.trim());
    if (await file.exists()) {
      return file.path;
    }

    savedPaths.remove('$alertId');
    await _saveDownloadedMediaPaths(_downloadedVoiceRecordingsKey, savedPaths);
    return null;
  }

  Future<String?> getDownloadedVideoRecordingPath(int alertId) async {
    final savedPaths = await _loadDownloadedMediaPaths(
      _downloadedVideoRecordingsKey,
    );
    final filePath = savedPaths['$alertId'];
    if ((filePath ?? '').trim().isEmpty) {
      return null;
    }

    final file = File(filePath!.trim());
    if (await file.exists()) {
      return file.path;
    }

    savedPaths.remove('$alertId');
    await _saveDownloadedMediaPaths(_downloadedVideoRecordingsKey, savedPaths);
    return null;
  }

  Future<String> saveVoiceRecordingToDevice(SosAlert alert) async {
    return _saveMediaToDevice(
      alert: alert,
      remoteUrl: alert.voiceRecordingUrl,
      prefsKey: _downloadedVoiceRecordingsKey,
      folderName: 'received_sos_recordings',
      filePrefix: 'panic_voice',
      fileMissingMessage:
          'Voice recording is no longer available online and has not been saved on this device yet.',
      downloadFailureMessage:
          'Could not download the voice recording right now.',
      getExistingPath: getDownloadedVoiceRecordingPath,
      remoteColumn: 'voice_recording_url',
    );
  }

  Future<String> saveVideoRecordingToDevice(SosAlert alert) async {
    return _saveMediaToDevice(
      alert: alert,
      remoteUrl: alert.videoRecordingUrl,
      prefsKey: _downloadedVideoRecordingsKey,
      folderName: 'received_sos_videos',
      filePrefix: 'panic_video',
      fileMissingMessage:
          'Video recording is no longer available online and has not been saved on this device yet.',
      downloadFailureMessage:
          'Could not download the video recording right now.',
      getExistingPath: getDownloadedVideoRecordingPath,
      remoteColumn: 'video_recording_url',
    );
  }

  Future<_PushDispatchSummary> _dispatchPushAlerts(dynamic insertedRows) async {
    final alerts = (insertedRows as List)
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => {
            'alertId': row['id'],
            'sessionId': row['session_id'],
            'recipientUserId': row['recipient_user_id'],
            'senderName': row['sender_name'],
            'alertMessage': row['alert_message'],
          },
        )
        .toList();
    if (alerts.isEmpty) {
      return const _PushDispatchSummary(deliveredCount: 0, skippedCount: 0);
    }

    try {
      final response = await _supabase.functions.invoke(
        'send-sos-push',
        body: {'alerts': alerts},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final errorMessage = (data['error'] ?? '').toString().trim();
        return _PushDispatchSummary(
          deliveredCount:
              int.tryParse((data['sentCount'] ?? '0').toString()) ?? 0,
          skippedCount:
              int.tryParse((data['skippedCount'] ?? '0').toString()) ?? 0,
          errorMessage: errorMessage.isEmpty ? null : errorMessage,
        );
      }
      return const _PushDispatchSummary(deliveredCount: 0, skippedCount: 0);
    } catch (error) {
      debugPrint('SOS push dispatch failed: $error');
      return _PushDispatchSummary(
        deliveredCount: 0,
        skippedCount: alerts.length,
        errorMessage:
            'Push notifications are not configured yet. Deploy the send-sos-push function and set the Firebase service account secret in Supabase.',
      );
    }
  }

  String _resolveSenderName(AegixaPublicProfile? profile) {
    final user = FirebaseAuth.instance.currentUser;
    final profileName = (profile?.displayName ?? '').trim();
    if (profileName.isNotEmpty) {
      return profileName;
    }
    final displayName = (user?.displayName ?? '').trim();
    if (displayName.isNotEmpty) {
      return displayName;
    }
    final email = (user?.email ?? '').trim();
    if (email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'Aegixa User';
  }

  Future<String?> _uploadMediaRecording({
    required String sessionId,
    required String localFilePath,
    required String fileStem,
  }) async {
    final file = File(localFilePath);
    if (!file.existsSync()) {
      return null;
    }

    final extension = path.extension(localFilePath).replaceFirst('.', '');
    final objectPath = extension.isEmpty
        ? '$_currentUserId/$sessionId/$fileStem'
        : '$_currentUserId/$sessionId/$fileStem.$extension';

    await _supabase.storage.from(_recordingsBucket).uploadBinary(
          objectPath,
          await file.readAsBytes(),
          fileOptions: const FileOptions(upsert: true),
        );

    return _supabase.storage.from(_recordingsBucket).getPublicUrl(objectPath);
  }

  Future<String> _saveMediaToDevice({
    required SosAlert alert,
    required String? remoteUrl,
    required String prefsKey,
    required String folderName,
    required String filePrefix,
    required String fileMissingMessage,
    required String downloadFailureMessage,
    required Future<String?> Function(int alertId) getExistingPath,
    required String remoteColumn,
  }) async {
    final existingPath = await getExistingPath(alert.id);
    if (existingPath != null) {
      return existingPath;
    }

    final normalizedUrl = (remoteUrl ?? '').trim();
    if (normalizedUrl.isEmpty) {
      throw StateError(fileMissingMessage);
    }

    final response = await http.get(Uri.parse(normalizedUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(downloadFailureMessage);
    }

    final mediaDirectory = Directory(
      path.join((await getApplicationDocumentsDirectory()).path, folderName),
    );
    await mediaDirectory.create(recursive: true);

    final extension = _resolveDownloadedRecordingExtension(normalizedUrl);
    final filePath = path.join(
      mediaDirectory.path,
      '${filePrefix}_${alert.sessionId}_${alert.id}$extension',
    );
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes, flush: true);

    final savedPaths = await _loadDownloadedMediaPaths(prefsKey);
    savedPaths['${alert.id}'] = file.path;
    await _saveDownloadedMediaPaths(prefsKey, savedPaths);
    await _cleanupRemoteMedia(alert, normalizedUrl, remoteColumn);
    return file.path;
  }

  Future<void> _cleanupRemoteMedia(
    SosAlert alert,
    String remoteUrl,
    String remoteColumn,
  ) async {
    final objectPath = _extractStorageObjectPath(remoteUrl);

    try {
      await _supabase
          .from(_table)
          .update({
            remoteColumn: null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', alert.id)
          .eq('recipient_user_id', _currentUserId);
    } catch (error) {
      debugPrint('Could not clear SOS media URL after download: $error');
      return;
    }

    if ((objectPath ?? '').isEmpty) {
      return;
    }

    try {
      final remainingRows = await _supabase
          .from(_table)
          .select('id')
          .eq(remoteColumn, remoteUrl)
          .limit(1);
      if (remainingRows.isNotEmpty) {
        return;
      }

      await _supabase.storage.from(_recordingsBucket).remove([objectPath!]);
    } catch (error) {
      debugPrint('Could not delete remote SOS media: $error');
    }
  }

  String _resolveDownloadedRecordingExtension(String remoteUrl) {
    final uri = Uri.tryParse(remoteUrl);
    final extension = path.extension(uri?.path ?? '').trim();
    if (extension.isNotEmpty && extension.length <= 8) {
      return extension;
    }
    return '.m4a';
  }

  String? _extractStorageObjectPath(String remoteUrl) {
    if (remoteUrl.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(remoteUrl);
    if (uri == null) {
      return null;
    }

    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf(_recordingsBucket);
    if (bucketIndex == -1 || bucketIndex + 1 >= segments.length) {
      return null;
    }
    return segments.sublist(bucketIndex + 1).join('/');
  }

  Future<Map<String, String>> _loadDownloadedMediaPaths(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if ((raw ?? '').trim().isEmpty) {
      return <String, String>{};
    }

    try {
      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, (value ?? '').toString()),
      );
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _saveDownloadedMediaPaths(
    String key,
    Map<String, String> paths,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(paths));
  }

  String _friendlySupabaseError(PostgrestException error) {
    final message = error.message.trim();
    final lower = message.toLowerCase();
    if (lower.contains('could not find the table') &&
        lower.contains('sos_alerts')) {
      return 'Supabase SOS setup is incomplete. Run `supabase_sos_alerts_schema.sql` to create the `sos_alerts` table.';
    }
    if (lower.contains('video_recording_url') ||
        lower.contains('voice_recording_url')) {
      return 'Supabase SOS media columns are missing. Re-run `supabase_sos_alerts_schema.sql`.';
    }
    if (lower.contains('row-level security') ||
        lower.contains('permission denied') ||
        lower.contains('violates row-level security')) {
      return 'Supabase SOS permissions are blocking this action. Re-run `supabase_sos_alerts_schema.sql`.';
    }
    if (message.isNotEmpty) {
      return message;
    }
    return 'Supabase SOS request failed.';
  }

  String _friendlyStorageError(StorageException error) {
    final message = error.message.trim();
    final lower = message.toLowerCase();
    if (lower.contains('bucket')) {
      return 'Supabase SOS recording storage is not set up. Re-run `supabase_sos_alerts_schema.sql`.';
    }
    if (message.isNotEmpty) {
      return message;
    }
    return 'Could not upload the SOS voice recording.';
  }
}
