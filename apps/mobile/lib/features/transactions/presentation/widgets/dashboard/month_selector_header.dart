import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

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
        // Generar últimos 12 meses + próximos 2 meses
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
                      icon: const Icon(Icons.close_rounded),
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
                              ? Icons.radio_button_checked_rounded
                              : Icons.calendar_month_outlined,
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
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Actual',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(sheetContext).pop(item);
                        },
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
    final cubit = context.read<DashboardCubit>();
    final monthName = DateFormat('MMMM yyyy', 'es').format(summary.month);
    final isCurrent = _isCurrentMonth(summary.month);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Selector interactivo de mes
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showMonthPicker(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    monthName[0].toUpperCase() + monthName.substring(1),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          // Botones de navegación y retorno a Hoy
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isCurrent)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.today_rounded, size: 14),
                    label: const Text('Hoy'),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      cubit.goToCurrentMonth();
                    },
                  ),
                ),
              IconButton.filledTonal(
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Mes anterior',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  cubit.previousMonth();
                },
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Mes siguiente',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  cubit.nextMonth();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
