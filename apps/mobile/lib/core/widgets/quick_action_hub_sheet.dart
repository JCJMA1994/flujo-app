import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/capture/presentation/widgets/qr_scanner_sheet.dart';
import '../../features/transactions/presentation/widgets/transaction_form_sheet.dart';
import '../router/app_router.dart';

/// Modal central de acciones rápidas activado desde el botón central flotante.
class QuickActionHubSheet extends StatelessWidget {
  const QuickActionHubSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 580),
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickActionHubSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Row(
            children: [
              Text(
                '¿Cómo quieres registrar?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              IconButton.filledTonal(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Opción 1: Manualmente
          _ActionCard(
            title: 'Manualmente',
            subtitle: 'Ingresa los datos tú mismo',
            icon: Icons.edit_outlined,
            onTap: () {
              Navigator.of(context).pop();
              TransactionFormSheet.show(context);
            },
          ),
          const SizedBox(height: 12),

          // Opción 2: Escanear QR
          _ActionCard(
            title: 'Escanear QR',
            subtitle: 'Desde tu comprobante',
            icon: Icons.qr_code_scanner_rounded,
            onTap: () {
              Navigator.of(context).pop();
              QrScannerSheet.show(context);
            },
          ),
          const SizedBox(height: 12),

          // Opción 3: Con asistente
          _ActionCard(
            title: 'Con asistente',
            subtitle: 'Describe tu movimiento',
            icon: Icons.chat_bubble_outline_rounded,
            onTap: () {
              Navigator.of(context).pop();
              context.push(AppRoutes.chat);
            },
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color(0xFF134E4A)
                      : const Color(0xFFCCFBF1),
                ),
                child: Icon(
                  icon,
                  color: isDark
                      ? const Color(0xFF2DD4BF)
                      : const Color(0xFF0F766E),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
