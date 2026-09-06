import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../domain/entities/transaction.dart';
import '../../cubit/dashboard_cubit.dart';

class MonthSelectorHeader extends StatelessWidget {
  const MonthSelectorHeader({required this.summary, super.key});

  final MonthlySummary summary;

  bool _isCurrentMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  Future<void> _showMonthPicker(BuildContext context) async {
    final cubit = context.read<DashboardCubit>();
    final theme = Theme.of(context);
    final now = DateTime.now();
    final currentSelected = summary.month;

    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final months = List.generate(15, (index) {
          final m = now.month - 12 + index;
          return DateTime(now.year, m);
        }).reversed.toList();

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Seleccionar período',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: months.length,
                    itemBuilder: (context, index) {
                      final item = months[index];
                      final isSelected = item.year == currentSelected.year &&
                          item.month == currentSelected.month;
                      final isNow = _isCurrentMonth(item);
                      final label = DateFormat('MMMM yyyy', 'es').format(item);
                      final capitalized =
                          label[0].toUpperCase() + label.substring(1);

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        selected: isSelected,
                        selectedTileColor: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.5),
                        leading: Icon(
                          isSelected
                              ? LucideIcons.checkCircle2
                              : LucideIcons.calendar,
                          size: 20,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          capitalized,
                          style: TextStyle(
                            fontWeight: isSelected || isNow
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isNow
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Actual',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () => Navigator.of(sheetContext).pop(item),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      cubit.selectMonth(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cubit = context.read<DashboardCubit>();
    final monthName = DateFormat('MMMM yyyy', 'es').format(summary.month);
    final capitalized = monthName[0].toUpperCase() + monthName.substring(1);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(LucideIcons.chevronLeft, size: 18),
              tooltip: 'Mes anterior',
              onPressed: () {
                HapticFeedback.selectionClick();
                cubit.previousMonth();
              },
            ),
            const SizedBox(width: 2),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _showMonthPicker(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      capitalized,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark
                            ? const Color(0xFFF8FAFC)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      LucideIcons.chevronDown,
                      size: 15,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(LucideIcons.chevronRight, size: 18),
              tooltip: 'Mes siguiente',
              onPressed: () {
                HapticFeedback.selectionClick();
                cubit.nextMonth();
              },
            ),
          ],
        ),
      ),
    );
  }
}
