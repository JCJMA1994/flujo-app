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
                'Nuevo Registro',
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
          const SizedBox(height: 16),

          // Opción 1: Escanear QR SUNAT
          _ActionCard(
            title: 'Escanear Boleta o Factura (QR)',
            subtitle: 'Pagos en efectivo con ticket impreso SUNAT',
            icon: Icons.qr_code_scanner_rounded,
            gradient: const [Color(0xFF0D9488), Color(0xFF2DD4BF)],
            badge: 'EFECTIVO',
            onTap: () {
              Navigator.of(context).pop();
              QrScannerSheet.show(context);
            },
          ),
          const SizedBox(height: 12),

          // Opción 2: Movimiento Manual
          _ActionCard(
            title: 'Registrar Movimiento Manual',
            subtitle: 'Gasto o ingreso con categoría y comercio',
            icon: Icons.edit_note_rounded,
            gradient: const [Color(0xFF4F46E5), Color(0xFF818CF8)],
            onTap: () {
              Navigator.of(context).pop();
              TransactionFormSheet.show(context);
            },
          ),
          const SizedBox(height: 12),

          // Opción 3: Chat con IA
          _ActionCard(
            title: 'Consultar Asistente Financiero',
            subtitle: 'Pregúntale a Gemini sobre tus gastos o balances',
            icon: Icons.auto_awesome_rounded,
            gradient: const [Color(0xFF0284C7), Color(0xFF38BDF8)],
            badge: 'IA',
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
    required this.gradient,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.first.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: gradient.first.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: gradient.first,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
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
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
