import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  
  static bool _isInitialized = false;

  /// Initialize notification services
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize timezone data
      tz_data.initializeTimeZones();
      
      // Initialize local notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channels for Android
      await _createNotificationChannels();
      
      _isInitialized = true;
    } catch (e) {
    }
  }

  /// Create notification channels for Android
  static Future<void> _createNotificationChannels() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Habit Reminders Channel
      const AndroidNotificationChannel habitChannel = AndroidNotificationChannel(
        'habit_reminders',
        'Habit Reminders',
        description: 'Notifications for habit reminders',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      // General Notifications Channel
      const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
        'general',
        'General Notifications',
        description: 'General app notifications',
        importance: Importance.defaultImportance,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(habitChannel);

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(generalChannel);
    }
  }

  /// Request notification permissions
  static Future<bool> requestPermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android 13+ requires notification permission
        final status = await Permission.notification.request();
        debugPrint('Android notification permission: ${status.name}');
        return status.isGranted;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        // iOS notification permissions
        final settings = await _firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          announcement: false,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
        );
        debugPrint('iOS notification permission: ${settings.authorizationStatus.name}');
        return settings.authorizationStatus == AuthorizationStatus.authorized;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
      return false;
    }
  }

  /// Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await Permission.notification.isGranted;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final settings = await _firebaseMessaging.getNotificationSettings();
        return settings.authorizationStatus == AuthorizationStatus.authorized;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error checking notification status: $e');
      return false;
    }
  }

  /// Schedule a habit reminder
  static Future<void> scheduleHabitReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required String habitId,
    String period = 'daily',
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final androidDetails = AndroidNotificationDetails(
        'habit_reminders',
        'Habit Reminders',
        channelDescription: 'Notifications for habit reminders',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        actions: [
          const AndroidNotificationAction(
            'mark_done',
            'Mark Done',
            showsUserInterface: true,
          ),
          const AndroidNotificationAction(
            'snooze',
            'Snooze 10min',
            showsUserInterface: false,
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        categoryIdentifier: 'HABIT_REMINDER',
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Schedule based on period
      final now = tz.TZDateTime.now(tz.local);
      tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If the time has passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      switch (period.toLowerCase()) {
        case 'daily':
          await _localNotifications.zonedSchedule(
            id,
            title,
            body,
            scheduledDate,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            payload: habitId,
            matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
          );
          break;
        
        case 'weekly':
          await _localNotifications.zonedSchedule(
            id,
            title,
            body,
            scheduledDate,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            payload: habitId,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // Repeat weekly
          );
          break;
        
        case 'monthly':
          await _localNotifications.zonedSchedule(
            id,
            title,
            body,
            scheduledDate,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            payload: habitId,
            matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime, // Repeat monthly
          );
          break;
      }

      debugPrint('✅ Scheduled $period habit reminder: $title at $hour:$minute');
    } catch (e) {
      debugPrint('❌ Error scheduling habit reminder: $e');
    }
  }

  /// Cancel a specific notification
  static Future<void> cancelNotification(int id) async {
    try {
      await _localNotifications.cancel(id);
      debugPrint('✅ Cancelled notification: $id');
    } catch (e) {
      debugPrint('❌ Error cancelling notification: $e');
    }
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      debugPrint('✅ Cancelled all notifications');
    } catch (e) {
      debugPrint('❌ Error cancelling all notifications: $e');
    }
  }

  /// Show immediate notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      const androidDetails = AndroidNotificationDetails(
        'general',
        'General Notifications',
        channelDescription: 'General app notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      debugPrint('✅ Showed notification: $title');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  /// Get pending notifications
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _localNotifications.pendingNotificationRequests();
    } catch (e) {
      debugPrint('❌ Error getting pending notifications: $e');
      return [];
    }
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    debugPrint('📱 Notification tapped with payload: $payload');
    
    if (payload != null) {
      // Handle different actions
      switch (response.actionId) {
        case 'mark_done':
          debugPrint('🎯 Mark Done action tapped for habit: $payload');
          // TODO: Mark habit as completed
          break;
        case 'snooze':
          debugPrint('⏰ Snooze action tapped for habit: $payload');
          // TODO: Snooze notification for 10 minutes
          break;
        default:
          debugPrint('📱 Default tap action for habit: $payload');
          // TODO: Navigate to habit tracking page
          break;
      }
    }
  }

  /// Get FCM token for push notifications
  static Future<String?> getFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      debugPrint('🔑 FCM Token: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Setup FCM message handlers
  static void setupFCMHandlers() {
    try {
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📨 Received foreground message: ${message.messageId}');
        
        if (message.notification != null) {
          showNotification(
            id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title: message.notification!.title ?? 'Habit Reminder',
            body: message.notification!.body ?? 'Time for your habit!',
            payload: message.data['habitId'],
          );
        }
      });

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
    } catch (e) {
    }
  }

  /// Background message handler
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    debugPrint('📨 Handling background message: ${message.messageId}');
    // Handle background message processing here
  }

  /// Generate unique notification ID from habit name and period
  static int generateNotificationId(String habitName, String period) {
    return '${habitName}_$period'.hashCode.abs() % 2147483647; // Max int32
  }
}
