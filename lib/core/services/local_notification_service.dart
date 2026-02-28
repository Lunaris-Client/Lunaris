import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum NotificationChannel {
  general('lunaris_general', 'General', 'General Discourse notifications'),
  chat('lunaris_chat', 'Chat Messages', 'New chat messages'),
  mentions('lunaris_mentions', 'Mentions', 'When someone mentions you'),
  replies('lunaris_replies', 'Replies', 'Replies to your posts'),
  likes('lunaris_likes', 'Likes', 'When someone likes your post'),
  messages('lunaris_messages', 'Private Messages', 'Direct and group messages');

  final String id;
  final String name;
  final String description;
  const NotificationChannel(this.id, this.name, this.description);

  Importance get importance =>
      this == likes ? Importance.defaultImportance : Importance.high;

  Priority get priority =>
      this == likes ? Priority.defaultPriority : Priority.high;
}

class NotificationPayload {
  final String serverUrl;
  final String type;
  final int? topicId;
  final int? postNumber;
  final int? chatChannelId;
  final int? chatMessageId;

  const NotificationPayload({
    required this.serverUrl,
    required this.type,
    this.topicId,
    this.postNumber,
    this.chatChannelId,
    this.chatMessageId,
  });

  String encode() => jsonEncode({
    'serverUrl': serverUrl,
    'type': type,
    if (topicId != null) 'topicId': topicId,
    if (postNumber != null) 'postNumber': postNumber,
    if (chatChannelId != null) 'chatChannelId': chatChannelId,
    if (chatMessageId != null) 'chatMessageId': chatMessageId,
  });

  static NotificationPayload? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return NotificationPayload(
        serverUrl: map['serverUrl'] as String,
        type: map['type'] as String? ?? 'notification',
        topicId: map['topicId'] as int?,
        postNumber: map['postNumber'] as int?,
        chatChannelId: map['chatChannelId'] as int?,
        chatMessageId: map['chatMessageId'] as int?,
      );
    } catch (_) {
      return null;
    }
  }
}

class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  void Function(NotificationPayload payload)? onNotificationTap;

  int _nextId = 0;

  int _generateId() {
    _nextId = (_nextId + 1) % 2147483647;
    return _nextId;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = NotificationPayload.decode(response.payload);
        if (payload != null) {
          onNotificationTap?.call(payload);
        }
      },
    );

    if (!kIsWeb && Platform.isAndroid) {
      await _createAndroidChannels();
    }

    _initialized = true;
  }

  Future<void> _createAndroidChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    for (final channel in NotificationChannel.values) {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          channel.id,
          channel.name,
          description: channel.description,
          importance: channel.importance,
        ),
      );
    }
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      final android =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      return await android?.requestNotificationsPermission() ?? false;
    }

    if (Platform.isIOS) {
      final ios =
          _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    if (Platform.isMacOS) {
      final macos =
          _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >();
      return await macos?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return true;
  }

  NotificationChannel _channelForType(int notificationType) {
    const replyTypes = {2, 9};
    const mentionTypes = {1, 3, 15};
    const likeTypes = {5, 19};
    const messageTypes = {6, 7, 16};
    const chatTypes = {29, 30, 31, 32, 40};

    if (chatTypes.contains(notificationType)) return NotificationChannel.chat;
    if (replyTypes.contains(notificationType)) return NotificationChannel.replies;
    if (mentionTypes.contains(notificationType)) return NotificationChannel.mentions;
    if (likeTypes.contains(notificationType)) return NotificationChannel.likes;
    if (messageTypes.contains(notificationType)) return NotificationChannel.messages;
    return NotificationChannel.general;
  }

  Future<void> show({
    required String title,
    required String body,
    NotificationPayload? payload,
    int? notificationType,
    NotificationChannel? channel,
  }) async {
    if (!_initialized) {
      debugPrint('[Notification] show() called but not initialized');
      return;
    }

    final effectiveChannel = channel
        ?? (notificationType != null ? _channelForType(notificationType) : NotificationChannel.general);

    debugPrint('[Notification] show: title="$title" body="${body.length > 60 ? '${body.substring(0, 60)}...' : body}" '
        'type=$notificationType channel=${effectiveChannel.id}');

    final androidDetails = AndroidNotificationDetails(
      effectiveChannel.id,
      effectiveChannel.name,
      channelDescription: effectiveChannel.description,
      importance: effectiveChannel.importance,
      priority: effectiveChannel.priority,
      groupKey: payload?.serverUrl,
    );

    const darwinDetails = DarwinNotificationDetails();
    const linuxDetails = LinuxNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
    );

    try {
      await _plugin.show(
        _generateId(),
        title,
        body,
        details,
        payload: payload?.encode(),
      );
    } catch (e) {
      debugPrint('[Notification] show() error: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }
}
