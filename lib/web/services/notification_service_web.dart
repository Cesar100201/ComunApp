import '../../core/contracts/notification_service.dart';

/// Implementación web de [NotificationService]. No-op; solo se usa en builds web.
class NotificationServiceWeb implements NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> showProgressNotification({
    required int progress,
    required int total,
    required String title,
    String? body,
  }) async {}

  @override
  Future<void> showCompletionNotification({
    required int total,
    required int successCount,
    required int errorCount,
  }) async {}

  @override
  Future<void> cancelProgressNotification() async {}

  @override
  Future<void> cancelAll() async {}
}
