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

  /// IDs para notificaciones de sincronización (persistentes, no eliminables)
  static const int syncProgressNotificationId = 2001;
  static const int syncCompleteNotificationId = 2002;
  static const int syncErrorNotificationId = 2003;
  static const String _syncChannelId = 'sync_progress';
  static const String _syncChannelName = 'Sincronización';

  /// Inicializa el servicio de notificaciones y solicita permiso en Android 13+.
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

    // Crear canales y solicitar permiso de notificaciones (Android)
    if (Platform.isAndroid) {
      // Android 13+ (API 33): hay que pedir permiso para que se vean las notificaciones
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      const bulkChannel = AndroidNotificationChannel(
        'bulk_upload_progress',
        'Carga Masiva de Datos',
        description: 'Progreso de carga masiva de habitantes',
        importance: Importance.high,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      );
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(bulkChannel);

      const syncChannel = AndroidNotificationChannel(
        _syncChannelId,
        _syncChannelName,
        description: 'Progreso de sincronización con la nube',
        importance: Importance.defaultImportance,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      );
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(syncChannel);
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

    const androidDetails = AndroidNotificationDetails(
      'bulk_upload_progress',
      'Carga Masiva de Datos',
      channelDescription: 'Notificación de finalización',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false, // Se puede eliminar
      autoCancel: true,
      showProgress: false,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
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

  // ========== Notificaciones de sincronización (persistentes, no eliminables) ==========

  /// Asegura que el servicio esté listo y con permiso (Android 13+). Llamar antes de mostrar la primera notificación.
  Future<void> ensureReady() async {
    if (!_initialized) await initialize();
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  /// Muestra la notificación de progreso de sincronización (fija en barra, no se puede deslizar).
  /// [progress] 0-100.
  Future<void> showSyncProgressNotification({
    required int progress,
    required String stepLabel,
    int subidos = 0,
    int descargados = 0,
  }) async {
    await ensureReady();

    final body = stepLabel;
    final detail = (subidos > 0 || descargados > 0)
        ? 'Subidos: $subidos · Descargados: $descargados'
        : null;
    final fullBody = detail != null ? '$body\n$detail' : body;

    final androidDetails = AndroidNotificationDetails(
      _syncChannelId,
      _syncChannelName,
      channelDescription: 'Progreso de sincronización',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      maxProgress: 100,
      progress: progress.clamp(0, 100),
      onlyAlertOnce: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: true,
      presentSound: false,
    );

    await _notifications.show(
      syncProgressNotificationId,
      'Sincronizando datos',
      fullBody,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  /// Oculta la notificación de progreso y muestra la de finalización (ya se puede eliminar).
  Future<void> showSyncCompleteNotification({
    required int subidos,
    required int descargados,
  }) async {
    await ensureReady();
    await _notifications.cancel(syncProgressNotificationId);

    final title = (subidos > 0 || descargados > 0)
        ? 'Sincronización completada'
        : 'Todo está al día';
    final body = (subidos > 0 || descargados > 0)
        ? 'Subidos: $subidos · Descargados: $descargados'
        : 'Datos local y nube sincronizados';

    const androidDetails = AndroidNotificationDetails(
      _syncChannelId,
      _syncChannelName,
      channelDescription: 'Resultado de sincronización',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: false,
      autoCancel: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _notifications.show(
      syncCompleteNotificationId,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  /// Oculta el progreso y muestra notificación de error (se puede eliminar).
  Future<void> showSyncErrorNotification(String message) async {
    await ensureReady();
    await _notifications.cancel(syncProgressNotificationId);

    const androidDetails = AndroidNotificationDetails(
      _syncChannelId,
      _syncChannelName,
      channelDescription: 'Errores de sincronización',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _notifications.show(
      syncErrorNotificationId,
      'Error de sincronización',
      message,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  /// Cancela solo la notificación de progreso de sincronización.
  Future<void> cancelSyncProgressNotification() async {
    await _notifications.cancel(syncProgressNotificationId);
  }
}
