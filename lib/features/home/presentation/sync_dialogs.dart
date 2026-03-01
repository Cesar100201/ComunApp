import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Funciones auxiliares para mostrar diálogos de sincronización.
///
/// Centraliza la lógica de UI de sincronización que antes
/// residía en `home_page.dart`, cumpliendo el Principio de
/// Responsabilidad Única (SRP).
class SyncDialogs {
  SyncDialogs._(); // No instanciable

  /// Diálogo para invitados: solo sincronización rápida o solicitar profunda.
  /// Retorna `true` = ejecutar rápida, `false` = solicitar profunda, `null` = cancelar.
  static Future<bool?> showInvitedSyncDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(ctx).colorScheme.outline,
              width: 1,
            ),
            boxShadow: AppColors.shadowLarge,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogHeader(
                ctx,
                title: 'Sincronización',
                subtitle: 'Elija una opción',
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    buildSyncOptionCard(
                      ctx: ctx,
                      icon: Icons.flash_on_rounded,
                      title: 'Sincronización rápida',
                      subtitle:
                          'Comunas, consejos, organizaciones, CLAPs, proyectos, solicitudes y bitácora.',
                      color: AppColors.info,
                      onTap: () => Navigator.pop(ctx, true),
                    ),
                    const SizedBox(height: 12),
                    buildSyncOptionCard(
                      ctx: ctx,
                      icon: Icons.cloud_queue_rounded,
                      title: 'Solicitar sincronización profunda',
                      subtitle:
                          'Un administrador revisará su solicitud y la autorizará.',
                      color: AppColors.primaryDark,
                      onTap: () => Navigator.pop(ctx, false),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, null),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(
                          ctx,
                        ).colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Muestra diálogo para elegir tipo de sincronización.
  /// Retorna `true` = profunda, `false` = rápida, `null` = cancelar.
  static Future<bool?> showSyncTypeDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(ctx).colorScheme.outline,
              width: 1,
            ),
            boxShadow: AppColors.shadowLarge,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogHeader(
                ctx,
                title: 'Tipo de Sincronización',
                subtitle: 'Elija cómo sincronizar con la nube',
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    buildSyncOptionCard(
                      ctx: ctx,
                      icon: Icons.flash_on_rounded,
                      title: 'Sincronización rápida',
                      subtitle:
                          'Comunas, consejos, organizaciones, CLAPs, proyectos, solicitudes y bitácora. Sin habitantes ni extranjeros.',
                      color: AppColors.info,
                      onTap: () => Navigator.pop(ctx, false),
                    ),
                    const SizedBox(height: 12),
                    buildSyncOptionCard(
                      ctx: ctx,
                      icon: Icons.cloud_sync_rounded,
                      title: 'Sincronización profunda',
                      subtitle:
                          'Todo lo anterior más habitantes y extranjeros. Sincronización completa.',
                      color: AppColors.primaryDark,
                      onTap: () => Navigator.pop(ctx, true),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, null),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(
                          ctx,
                        ).colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Diálogo de advertencia para cuota de Firebase excedida.
  static void showQuotaExceededDialog(
    BuildContext context, {
    int? registrosSubidos,
    int? registrosPendientes,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 28,
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Cuota de Firebase Excedida')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se ha alcanzado el límite diario de escrituras en Firebase.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            if (registrosSubidos != null)
              Text(
                '✓ Subidos: $registrosSubidos',
                style: const TextStyle(color: AppColors.success),
              ),
            if (registrosPendientes != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '⏳ Pendientes: $registrosPendientes',
                  style: const TextStyle(color: AppColors.warning),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              '• La cuota se reinicia cada 24 h\n• Intente sincronizar mañana',
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  // ── Helpers privados ──

  static Widget _buildDialogHeader(
    BuildContext ctx, {
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.sync_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  /// Card reutilizable para opciones de sincronización.
  static Widget buildSyncOptionCard({
    required BuildContext ctx,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(ctx).colorScheme.outline,
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.85)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        height: 1.35,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
