import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../domain/entities/transaction.dart';
import '../review_transaction_sheet.dart';

class PendingReviewBanner extends StatelessWidget {
  const PendingReviewBanner({
    required this.pendingTransactions,
    super.key,
  });

  final List<Transaction> pendingTransactions;

  @override
  Widget build(BuildContext context) {
    if (pendingTransactions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final count = pendingTransactions.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          ReviewTransactionSheet.show(context, pendingTransactions.first);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF451A03).withValues(alpha: 0.35)
                : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFFB45309)
                      : const Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count ${count == 1 ? "movimiento por revisar" : "movimientos por revisar"}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Revisa y confirma para mantener tus finanzas al día.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFFFDE68A).withValues(alpha: 0.8)
                            : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color:
                    isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
