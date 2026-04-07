import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(settings);

    final androidPlatform =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlatform?.requestNotificationsPermission();

    final iosPlatform =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosPlatform?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    _initialized = true;
  }

  Future<void> showOutOfZoneAlert({
    required double distanceMeters,
    required double radiusMeters,
  }) async {
    try {
      await _ensureInitialized();

      const androidDetails = AndroidNotificationDetails(
        'location_alerts',
        'Alertes de localisation',
        channelDescription:
            'Notifications lors du depassement de la zone de securite',
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final distanceLabel = distanceMeters.toStringAsFixed(0);
      final radiusLabel = radiusMeters.toStringAsFixed(0);
      await _plugin.show(
        1001,
        'Alerte de localisation',
        'La distance autorisee a ete depassee ($distanceLabel m > $radiusLabel m).',
        details,
      );
    } catch (e) {
      debugPrint('LocalNotificationService error: $e');
    }
  }
}
