import 'package:flutter/material.dart';

/// Tarjeta de acción unificada para menús y módulos.
/// Estética: barra lateral de acento, icono con gradiente pastel, sombras suaves.
class ModuleActionCard extends StatelessWidget {
  const ModuleActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.colorAccent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color? colorAccent;
  final VoidCallback onTap;

  static Color _darken(Color c, double amount) {
    return Color.lerp(c, const Color(0xFF212121), amount)!;
  }

  Color get _effectiveAccent => colorAccent ?? _darken(color, 0.25);

  /// Calcula si un color de fondo es "claro" para elegir un ícono contrastante.
  /// Los colores pastel tienen luminancia alta, por lo que el ícono debe ser oscuro.
  static Color _iconColorFor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.4 ? const Color(0xFF37474F) : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _effectiveAccent;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // En modo oscuro, los colores pastel claros deben ser menos opacos
    // para integrarse mejor con el fondo oscuro.
    final effectiveColor = isDark ? color.withValues(alpha: 0.85) : color;
    final effectiveAccent = isDark ? accent.withValues(alpha: 0.85) : accent;
    final iconColor = _iconColorFor(color);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: color.withValues(alpha: 0.12),
          highlightColor: color.withValues(alpha: 0.06),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border(
                left: BorderSide(color: effectiveAccent, width: 4),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: isDark ? 0.12 : 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [effectiveColor, effectiveAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: effectiveAccent.withValues(alpha: isDark ? 0.25 : 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 26, color: iconColor),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
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
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
