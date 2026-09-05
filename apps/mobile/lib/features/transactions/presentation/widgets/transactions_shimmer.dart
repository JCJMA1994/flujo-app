import 'package:flutter/material.dart';

import '../../../../core/widgets/shimmer_box.dart';

class TransactionsShimmer extends StatelessWidget {
  const TransactionsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Summary banner skeleton
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 120, height: 16, borderRadius: 6),
              ShimmerBox(width: 140, height: 16, borderRadius: 6),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Transaction item skeletons
        for (int i = 0; i < 7; i++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.25),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    ShimmerBox(width: 44, height: 44, borderRadius: 12),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 130, height: 15, borderRadius: 4),
                          SizedBox(height: 6),
                          ShimmerBox(width: 80, height: 12, borderRadius: 4),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ShimmerBox(width: 75, height: 16, borderRadius: 4),
                        SizedBox(height: 4),
                        ShimmerBox(width: 45, height: 11, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
