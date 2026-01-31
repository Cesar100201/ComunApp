import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/contracts/notification_service.dart';

/// Implementación móvil de [NotificationService]. Solo se usa en builds móvil/desktop.
class NotificationServiceMobile implements NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const int progressNotificationId = 1001;
  static const int completionNotificationId = 1002;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'bulk_upload_progress',
        'Carga Masiva de Datos',
        description: 'Notificaciones del progreso de carga masiva de habitantes',
        importance: Importance.high,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }

    _initialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notificación tocada: ${response.id}');
  }

  @override
  Future<void> showProgressNotification({
    required int progress,
    required int total,
    required String title,
    String? body,
  }) async {
    if (!_initialized) await initialize();

    final percentage = total > 0 ? ((progress / total) * 100).round() : 0;
    final progressText = body ?? 'Procesando: $progress de $total registros ($percentage%)';

    final androidDetails = AndroidNotificationDetails(
      'bulk_upload_progress',
      'Carga Masiva de Datos',
      channelDescription: 'Progreso de carga masiva',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      maxProgress: 100,
      progress: percentage,
      onlyAlertOnce: false,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      progressNotificationId,
      title,
      progressText,
      notificationDetails,
    );
  }

  @override
  Future<void> showCompletionNotification({
    required int total,
    required int successCount,
    required int errorCount,
  }) async {
    if (!_initialized) await initialize();

    await _notifications.cancel(progressNotificationId);

    final title = errorCount > 0
        ? 'Carga completada con advertencias'
        : 'Carga completada exitosamente';

    final body = errorCount > 0
        ? '$successCount de $total registros guardados. $errorCount errores.'
        : '$total registros guardados exitosamente';

    final androidDetails = AndroidNotificationDetails(
      'bulk_upload_progress',
      'Carga Masiva de Datos',
      channelDescription: 'Notificación de finalización',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
      showProgress: false,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      completionNotificationId,
      title,
      body,
      notificationDetails,
    );
  }

  @override
  Future<void> cancelProgressNotification() async {
    await _notifications.cancel(progressNotificationId);
  }

  @override
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
