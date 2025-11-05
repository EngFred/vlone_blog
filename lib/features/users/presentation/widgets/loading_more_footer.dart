import 'package:flutter/material.dart';
import 'package:vlone_blog_app/core/presentation/widgets/loading_indicator.dart';

/// A reusable footer widget that shows:
/// - nothing when hasMore == false
/// - a loading row when hasMore && loadMoreError == null
/// - an error + retry when loadMoreError != null
class LoadingMoreFooter extends StatelessWidget {
  final bool hasMore;
  final String? loadMoreError;
  final VoidCallback? onRetry;

  const LoadingMoreFooter({
    super.key,
    required this.hasMore,
    this.loadMoreError,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasMore) return const SizedBox.shrink();

    if (loadMoreError != null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              'Failed to load more users',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          children: [
            LoadingIndicator(size: 20),
            SizedBox(height: 8),
            Text(
              'Loading more users...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
