/// Contrato del servicio de notificaciones. Implementado por móvil (flutter_local_notifications) o web (no-op).
abstract class NotificationService {
  Future<void> initialize();

  Future<void> showProgressNotification({
    required int progress,
    required int total,
    required String title,
    String? body,
  });

  Future<void> showCompletionNotification({
    required int total,
    required int successCount,
    required int errorCount,
  });

  Future<void> cancelProgressNotification();

  Future<void> cancelAll();
}
