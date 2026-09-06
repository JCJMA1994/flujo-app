import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../core/router/app_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/transaction.dart';
import '../review_transaction_sheet.dart';

class RecentTransactionsCard extends StatelessWidget {
  const RecentTransactionsCard({
    required this.transactions,
    super.key,
  });

  final List<Transaction> transactions;

  IconData _getCategoryIcon(String categoryId) {
    return switch (categoryId) {
      'food' || 'delivery' => LucideIcons.utensils,
      'transport' => LucideIcons.car,
      'groceries' || 'shopping' => LucideIcons.shoppingBag,
      'services' => LucideIcons.zap,
      'health' => LucideIcons.heartPulse,
      'subscriptions' => LucideIcons.tv,
      'salary' ||
      'freelance' ||
      'investments' ||
      'gifts' ||
      'other_income' =>
        LucideIcons.arrowDownLeft,
      _ => LucideIcons.receipt,
    };
  }

  Color _getCategoryBg(String categoryId, bool isDark) {
    if (isDark) return const Color(0xFF334155);
    return switch (categoryId) {
      'food' || 'delivery' => const Color(0xFFDCFCE7),
      'transport' => const Color(0xFFE0F2FE),
      'groceries' || 'shopping' => const Color(0xFFFEF3C7),
      'services' => const Color(0xFFEDE9FE),
      'health' => const Color(0xFFFFE4E6),
      'salary' || 'freelance' || 'other_income' => const Color(0xFFCCFBF1),
      _ => const Color(0xFFF1F5F9),
    };
  }

  Color _getCategoryColor(String categoryId, bool isDark) {
    if (isDark) return Colors.white;
    return switch (categoryId) {
      'food' || 'delivery' => const Color(0xFF16A34A),
      'transport' => const Color(0xFF0284C7),
      'groceries' || 'shopping' => const Color(0xFFD97706),
      'services' => const Color(0xFF7C3AED),
      'health' => const Color(0xFFE11D48),
      'salary' || 'freelance' || 'other_income' => const Color(0xFF0F766E),
      _ => const Color(0xFF475569),
    };
  }

  String _formatSource(TransactionSource source) {
    return switch (source) {
      TransactionSource.manual => 'Manual',
      TransactionSource.bankNotification => 'Yape / Notificación',
      TransactionSource.email => 'Correo',
      TransactionSource.whatsapp => 'WhatsApp',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final recent = transactions.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Últimos movimientos',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.transactions),
              style: TextButton.styleFrom(
                foregroundColor: FlujoTokens.verdePetroleo,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                'Ver todos',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Lista de items
        if (recent.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    LucideIcons.receipt,
                    size: 36,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No hay movimientos registrados este mes',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: recent.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 64,
                endIndent: 16,
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, index) {
                final tx = recent[index];
                final isExpense = tx.type == TransactionType.expense;
                final icon = _getCategoryIcon(tx.category.id);
                final iconBg = _getCategoryBg(tx.category.id, isDark);
                final iconColor = _getCategoryColor(tx.category.id, isDark);
                final dateStr =
                    DateFormat('dd MMM, HH:mm', 'es').format(tx.occurredAt);

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  onTap: () => ReviewTransactionSheet.show(context, tx),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  title: Text(
                    tx.merchant.isNotEmpty ? tx.merchant : tx.category.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${_formatSource(tx.source)} • $dateStr',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!tx.reviewed) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF451A03)
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Por revisar',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFFFBBF24)
                                  : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isExpense ? "- " : "+ "}S/ ${tx.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isExpense
                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                              : FlujoTokens.verdePetroleo,
                        ),
                      ),
                      if (tx.reviewed)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            LucideIcons.circleCheck,
                            size: 13,
                            color: isDark
                                ? const Color(0xFF2DD4BF)
                                : FlujoTokens.verdePetroleo,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

        const SizedBox(height: 16),
        // Estado de sincronización
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.refreshCw,
                size: 12,
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Text(
                'Actualizado hace un momento',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
