import 'package:flutter/material.dart';

import '../../../../../core/widgets/shimmer_box.dart';

class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Month selector skeleton
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBox(width: 36, height: 36, borderRadius: 18),
                ShimmerBox(width: 140, height: 28, borderRadius: 10),
                ShimmerBox(width: 36, height: 36, borderRadius: 18),
              ],
            ),
            const SizedBox(height: 16),

            // Balance Hero Card skeleton
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 100, height: 16, borderRadius: 6),
                  SizedBox(height: 12),
                  ShimmerBox(width: 220, height: 42, borderRadius: 10),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 70, height: 14, borderRadius: 6),
                            SizedBox(height: 8),
                            ShimmerBox(width: 110, height: 22),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 70, height: 14, borderRadius: 6),
                            SizedBox(height: 8),
                            ShimmerBox(width: 110, height: 22),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Daily Budget Card skeleton
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShimmerBox(width: 30, height: 30),
                      SizedBox(width: 10),
                      ShimmerBox(width: 180, height: 14, borderRadius: 6),
                    ],
                  ),
                  SizedBox(height: 16),
                  ShimmerBox(width: 160, height: 32),
                  SizedBox(height: 12),
                  ShimmerBox(width: double.infinity, height: 14, borderRadius: 6),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Category breakdown skeleton
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBox(width: 140, height: 20, borderRadius: 6),
                ShimmerBox(width: 60, height: 16, borderRadius: 6),
              ],
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < 3; i++) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    ShimmerBox(width: 36, height: 36, borderRadius: 10),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 110, height: 14, borderRadius: 4),
                          SizedBox(height: 6),
                          ShimmerBox(width: 60, height: 12, borderRadius: 4),
                        ],
                      ),
                    ),
                    ShimmerBox(width: 70, height: 18, borderRadius: 6),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
