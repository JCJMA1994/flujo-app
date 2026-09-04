import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/transaction.dart';
import '../../cubit/privacy_cubit.dart';

class BalanceHeroCard extends StatelessWidget {
  const BalanceHeroCard({required this.summary, super.key});

  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    final isObscured = context.watch<PrivacyCubit?>()?.state.isObscured ?? false;
    final isNetPositive = summary.netBalance >= 0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isNetPositive
              ? [
                  const Color(0xFF042F2E),
                  const Color(0xFF0F766E),
                  const Color(0xFF0D9488),
                ]
              : [
                  const Color(0xFF7F1D1D),
                  const Color(0xFF991B1B),
                  const Color(0xFFDC2626),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: (isNetPositive
                    ? const Color(0xFF0D9488)
                    : const Color(0xFFDC2626))
                .withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'BALANCE NETO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: Colors.white70,
                ),
              ),
              Icon(
                isNetPositive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isObscured
                  ? 'S/ ••••••'
                  : '${isNetPositive ? '+' : '-'}S/ ${summary.netBalance.abs().toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_downward_rounded,
                          size: 14,
                          color: Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ingresos',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                isObscured
                                    ? 'S/ ••••'
                                    : 'S/ ${summary.incomeTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 28,
                  width: 1,
                  color: Colors.white24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          size: 14,
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gastos',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                isObscured
                                    ? 'S/ ••••'
                                    : 'S/ ${summary.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 28,
                  width: 1,
                  color: Colors.white24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.speed_rounded,
                          size: 14,
                          color: Colors.cyanAccent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Promedio/d',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                isObscured
                                    ? 'S/ ••••'
                                    : 'S/ ${summary.dailyAverage.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
