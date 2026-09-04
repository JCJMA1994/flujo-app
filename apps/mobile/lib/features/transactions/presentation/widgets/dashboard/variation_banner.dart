import 'package:flutter/material.dart';

class VariationBanner extends StatelessWidget {
  const VariationBanner({required this.variation, super.key});

  final double variation;

  @override
  Widget build(BuildContext context) {
    final isSaving = variation < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isSaving
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSaving
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.orange.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSaving ? Icons.savings_outlined : Icons.info_outline_rounded,
            size: 18,
            color: isSaving ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isSaving
                  ? 'Excelente: Gastaste ${(variation.abs() * 100).round()}% menos que el mes anterior.'
                  : 'Atención: Llevas ${(variation * 100).round()}% más que el mes anterior.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSaving ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
