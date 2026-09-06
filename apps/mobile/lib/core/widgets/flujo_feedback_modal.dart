import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

enum FlujoFeedbackType {
  success,
  error,
  warning,
  info,
  destructive,
}

/// Modal inferior estandarizado según el Sistema de Diseño "Flujo".
/// Reemplaza completamente los SnackBars por una experiencia modal limpia y moderna.
class FlujoFeedbackModal extends StatelessWidget {
  const FlujoFeedbackModal({
    required this.title,
    required this.message,
    this.type = FlujoFeedbackType.success,
    this.primaryButtonLabel = 'Entendido',
    this.secondaryButtonLabel,
    this.onPrimaryPressed,
    this.onSecondaryPressed,
    this.customIcon,
    this.customContent,
    super.key,
  });

  final String title;
  final String message;
  final FlujoFeedbackType type;
  final String primaryButtonLabel;
  final String? secondaryButtonLabel;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;
  final IconData? customIcon;
  final Widget? customContent;

  /// Modal de éxito informativo.
  static Future<void> showSuccess(
    BuildContext context, {
    required String title,
    required String message,
    String buttonLabel = 'Entendido',
    VoidCallback? onDismiss,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 540),
      backgroundColor: Colors.transparent,
      builder: (ctx) => FlujoFeedbackModal(
        title: title,
        message: message,
        primaryButtonLabel: buttonLabel,
        onPrimaryPressed: () {
          Navigator.of(ctx).pop();
          onDismiss?.call();
        },
      ),
    );
  }

  /// Modal de error con explicación clara.
  static Future<void> showError(
    BuildContext context, {
    required String title,
    required String message,
    String buttonLabel = 'Cerrar',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 540),
      backgroundColor: Colors.transparent,
      builder: (ctx) => FlujoFeedbackModal(
        title: title,
        message: message,
        type: FlujoFeedbackType.error,
        primaryButtonLabel: buttonLabel,
        onPrimaryPressed: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  /// Modal de confirmación interactivo (ej. eliminar, crear regla).
  static Future<bool?> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
    bool isDestructive = false,
    IconData? customIcon,
    Widget? customContent,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 540),
      backgroundColor: Colors.transparent,
      builder: (ctx) => FlujoFeedbackModal(
        title: title,
        message: message,
        type: isDestructive
            ? FlujoFeedbackType.destructive
            : FlujoFeedbackType.warning,
        customIcon: customIcon,
        customContent: customContent,
        primaryButtonLabel: confirmLabel,
        secondaryButtonLabel: cancelLabel,
        onPrimaryPressed: () => Navigator.of(ctx).pop(true),
        onSecondaryPressed: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (iconBg, iconColor, defaultIcon) = switch (type) {
      FlujoFeedbackType.success => (
          isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1),
          isDark ? const Color(0xFF2DD4BF) : FlujoTokens.verdePetroleo,
          LucideIcons.checkCheck,
        ),
      FlujoFeedbackType.error => (
          isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
          isDark ? const Color(0xFFF87171) : FlujoTokens.crimson,
          LucideIcons.alertCircle,
        ),
      FlujoFeedbackType.warning => (
          isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
          isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
          LucideIcons.sparkles,
        ),
      FlujoFeedbackType.info => (
          isDark ? const Color(0xFF082F49) : const Color(0xFFE0F2FE),
          isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
          LucideIcons.info,
        ),
      FlujoFeedbackType.destructive => (
          isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
          isDark ? const Color(0xFFF87171) : FlujoTokens.crimson,
          LucideIcons.trash2,
        ),
    };

    final isDestructive = type == FlujoFeedbackType.destructive;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Ícono central estilizado
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              customIcon ?? defaultIcon,
              color: iconColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 18),

          // Título
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 19,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Mensaje
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),

          if (customContent != null) ...[
            const SizedBox(height: 16),
            customContent!,
          ],

          const SizedBox(height: 26),

          // Acciones
          Row(
            children: [
              if (secondaryButtonLabel != null) ...[
                Expanded(
                  child: SizedBox(
                    height: FlujoTokens.alturaBoton,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            FlujoTokens.radioTarjetas,
                          ),
                        ),
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      onPressed: onSecondaryPressed ??
                          () => Navigator.of(context).pop(false),
                      child: Text(
                        secondaryButtonLabel!,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: SizedBox(
                  height: FlujoTokens.alturaBoton,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: isDestructive
                          ? FlujoTokens.crimson
                          : FlujoTokens.verdePetroleo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          FlujoTokens.radioTarjetas,
                        ),
                      ),
                      elevation: 0,
                    ),
                    onPressed: onPrimaryPressed ??
                        () => Navigator.of(context).pop(true),
                    child: Text(
                      primaryButtonLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
