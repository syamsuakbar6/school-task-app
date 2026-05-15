import 'package:flutter/material.dart';

class LoadingList extends StatelessWidget {
  const LoadingList({
    super.key,
    this.itemCount = 6,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _LoadingBlock(
                  width: 44,
                  height: 44,
                  color: colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LoadingBlock(
                        width: double.infinity,
                        height: 14,
                        color: colorScheme.surfaceContainerHighest,
                      ),
                      const SizedBox(height: 8),
                      _LoadingBlock(
                        width: 140,
                        height: 12,
                        color: colorScheme.surfaceContainerHighest,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
