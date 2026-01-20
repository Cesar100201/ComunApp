import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

/// Servicio para manejar notificaciones locales
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// ID constante para la notificación de progreso de carga
  static const int progressNotificationId = 1001;
  
  /// ID constante para la notificación de finalización
  static const int completionNotificationId = 1002;

  /// Inicializa el servicio de notificaciones
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

    // Crear canal para notificaciones de progreso (Android)
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'bulk_upload_progress', // id
        'Carga Masiva de Datos', // nombre
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

  /// Callback cuando se toca una notificación
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notificación tocada: ${response.id}');
  }

  /// Muestra una notificación de progreso persistente (no se puede deslizar para eliminar)
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
      ongoing: true, // Notificación persistente (no se puede deslizar)
      autoCancel: false, // No se cancela automáticamente
      showProgress: true,
      maxProgress: 100,
      progress: percentage,
      onlyAlertOnce: false, // Actualizar siempre
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

  /// Muestra una notificación de finalización
  Future<void> showCompletionNotification({
    required int total,
    required int successCount,
    required int errorCount,
  }) async {
    if (!_initialized) await initialize();

    // Primero, cancelar la notificación de progreso
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
      ongoing: false, // Se puede eliminar
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

  /// Cancela la notificación de progreso
  Future<void> cancelProgressNotification() async {
    await _notifications.cancel(progressNotificationId);
  }

  /// Cancela todas las notificaciones
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
