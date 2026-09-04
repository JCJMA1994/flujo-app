import 'package:flutter/material.dart';

class VariationBanner extends StatelessWidget {
  const VariationBanner({
    required this.variation,
    this.absoluteDifference,
    super.key,
  });

  final double variation;
  final double? absoluteDifference;

  @override
  Widget build(BuildContext context) {
    final isSaving = variation < 0;
    final percentText = '${(variation.abs() * 100).toStringAsFixed(1)}%';
    final amountText = absoluteDifference != null
        ? ' (S/ ${absoluteDifference!.abs().toStringAsFixed(2)})'
        : '';

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = isSaving
        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
        : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706));

    final backgroundColor = isSaving
        ? (isDark
            ? const Color(0xFF064E3B).withValues(alpha: 0.3)
            : const Color(0xFFECFDF5))
        : (isDark
            ? const Color(0xFF78350F).withValues(alpha: 0.3)
            : const Color(0xFFFFFBEB));

    final borderColor = isSaving
        ? (isDark
            ? const Color(0xFF059669).withValues(alpha: 0.4)
            : const Color(0xFFA7F3D0))
        : (isDark
            ? const Color(0xFFD97706).withValues(alpha: 0.4)
            : const Color(0xFFFDE68A));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSaving ? Icons.savings_rounded : Icons.trending_up_rounded,
              size: 16,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSaving
                  ? 'Ritmo favorable: Gastaste $percentText menos que el mes anterior$amountText.'
                  : 'Atención: Llevas $percentText más de gasto que el mes anterior$amountText.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryColor,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
