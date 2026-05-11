import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzData;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tzData.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));

    const AndroidInitializationSettings initAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initIOS = DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: initAndroid,
      iOS: initIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(settings: initSettings);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleExpiryNotification(
    String ingredient,
    DateTime expiryDate,
  ) async {
    final tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
      9,
      0,
      0,
    );

    // Don't schedule if the date is already in the past
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    final int notificationId =
        (ingredient.hashCode ^ expiryDate.hashCode) & 0x7FFFFFFF;

    const NotificationDetails platformSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'expiry_channel', // Positional 1 (MUST be just the string)
        'Expiry Notifications', // Positional 2 (MUST be just the string)
        channelDescription: 'Alerts for expiring ingredients',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    // EVERYTHING here is a named argument now, and UILocalNotificationDateInterpretation is completely gone!
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: notificationId,
      title: 'Ingredient Expiring Today!',
      body:
          'Your $ingredient is expiring today. Time to cook something delicious!',
      scheduledDate: scheduledDate,
      notificationDetails: platformSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelNotification(
    String ingredient,
    DateTime expiryDate,
  ) async {
    final int notificationId =
        (ingredient.hashCode ^ expiryDate.hashCode) & 0x7FFFFFFF;

    // They changed this to require the 'id:' name as well!
    await flutterLocalNotificationsPlugin.cancel(id: notificationId);
  }

  // --- NEW: INSTANT PRICE DROP NOTIFICATION ---
  Future<void> showPriceDropNotification(
    String ingredient,
    double newPrice,
    String storeName,
  ) async {
    final int notificationId = ingredient.hashCode & 0x7FFFFFFF;

    const NotificationDetails platformSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'price_drop_channel',
        'Price Drop Alerts',
        channelDescription:
            'Alerts when ingredient prices drop below your target',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(''), // Allows long text
      ),
      iOS: DarwinNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.show(
      id: notificationId,
      title: 'Price Drop Alert! 📉',
      body:
          '$ingredient is down to RM ${newPrice.toStringAsFixed(2)} at $storeName!',
      notificationDetails: platformSpecifics,
    );
  }
}
