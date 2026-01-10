import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FCMService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Android notification channel for high priority notifications
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'fcm_default_channel',
    'FCM Notifications',
    description: 'High priority notifications from DenteEase',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Initialize FCM settings and listeners
  static Future<void> initialize() async {
    // 1. Request Permissions (especially for iOS and Android 13+)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else {
      debugPrint('User declined or has not accepted permission');
    }

    // 2. Create the notification channel for Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 3. Get and log the FCM Token
    String? token = await _firebaseMessaging.getToken();
    debugPrint('FCM Token: $token');

    // 4. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint(
            'Message also contained a notification: ${message.notification?.title}');
        _showLocalNotification(message);
      }
    });

    // 5. Handle when app is opened from a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('A new onMessageOpenedApp event was published!');
      // Handle navigation here if needed
    });

    // 6. Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token refreshed: $newToken');
      // Token will be saved on next login
    });

    // 7. Check for initial message (app opened from terminated state)
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
          'App opened from terminated state with message: ${initialMessage.messageId}');
    }
  }

  /// Save FCM token to Supabase for a specific user
  ///
  /// [userId] - The user's ID (patient_id, dentist_id, or staff_id)
  /// [tableName] - The table to update ('patients', 'dentists', or 'staffs')
  /// [idColumn] - The ID column name ('patient_id', 'dentist_id', or 'staff_id')
  static Future<bool> saveUserToken({
    required String userId,
    required String tableName,
    required String idColumn,
  }) async {
    try {
      // Get the current FCM token
      final String? token = await _firebaseMessaging.getToken();

      if (token == null) {
        debugPrint('FCM Token is null, cannot save to Supabase');
        return false;
      }

      debugPrint('Saving FCM token for $tableName.$idColumn = $userId');

      // Update the token in Supabase
      await Supabase.instance.client
          .from(tableName)
          .update({'fcm_token': token}).eq(idColumn, userId);

      debugPrint('FCM token saved successfully for $userId');
      return true;
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
      return false;
    }
  }

  /// Subscribe admin to admin_alerts topic for notifications
  static Future<bool> subscribeAdminToTopic() async {
    try {
      await _firebaseMessaging.subscribeToTopic('admin_alerts');
      debugPrint('Admin subscribed to admin_alerts topic');
      return true;
    } catch (e) {
      debugPrint('Error subscribing to admin topic: $e');
      return false;
    }
  }

  /// Unsubscribe admin from admin_alerts topic
  static Future<bool> unsubscribeAdminFromTopic() async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic('admin_alerts');
      debugPrint('Admin unsubscribed from admin_alerts topic');
      return true;
    } catch (e) {
      debugPrint('Error unsubscribing from admin topic: $e');
      return false;
    }
  }

  /// Show a local notification for foreground messages
  static void _showLocalNotification(RemoteMessage message) {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'fcm_default_channel',
      'FCM Notifications',
      channelDescription: 'High priority notifications from DenteEase',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Notification',
      message.notification?.body ?? '',
      details,
    );
  }
}
