import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Extrae la URL de creación de índice de Firestore del mensaje de error, si existe.
String? extractIndexUrl(String error) {
  final start = error.indexOf('https://console.firebase.google.com');
  if (start == -1) return null;
  final end = error.indexOf(RegExp(r'\s'), start);
  if (end == -1) return error.substring(start);
  return error.substring(start, end);
}

/// Muestra el error en un diálogo (alerta). Si el mensaje contiene el enlace
/// de Firebase para crear índice, ofrece un botón para abrirlo.
Future<void> showFormacionErrorAlert(
  BuildContext context, {
  required String error,
  VoidCallback? onRetry,
}) async {
  final indexUrl = extractIndexUrl(error);
  final shortMessage = error.length > 200 ? '${error.substring(0, 200)}…' : error;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Error'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(shortMessage),
            if (indexUrl != null) ...[
              const SizedBox(height: 12),
              Text(
                'Si el error indica que falta un índice, puede crearlo desde el enlace siguiente.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (indexUrl != null)
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.tryParse(indexUrl);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Abrir enlace para crear índice'),
          ),
        if (onRetry != null)
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onRetry();
            },
            child: const Text('Reintentar'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
