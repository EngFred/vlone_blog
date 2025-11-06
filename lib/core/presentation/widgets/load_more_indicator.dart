import 'package:flutter/material.dart';
import 'loading_indicator.dart';

class LoadMoreIndicator extends StatelessWidget {
  final String message;
  final double indicatorSize;
  final double spacing;

  const LoadMoreIndicator({
    super.key,
    this.message = 'Loading more posts...',
    this.indicatorSize = 20.0,
    this.spacing = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LoadingIndicator(size: indicatorSize),
            SizedBox(height: spacing),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
