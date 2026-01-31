// Puntos de entrada separados por plataforma (plan versión web).
// Móvil/desktop: main_mobile.dart (Isar, notificaciones, SyncService).
// Web: main_web.dart (solo Firebase). No se usa kIsWeb.
import 'main_stub.dart'
    if (dart.library.io) 'main_mobile.dart'
    if (dart.library.html) 'main_web.dart' as entry;

void main() => entry.main();
