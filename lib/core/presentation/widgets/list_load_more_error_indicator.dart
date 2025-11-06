import 'package:flutter/material.dart';

class LoadMoreErrorIndicator extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final double horizontalMargin;

  const LoadMoreErrorIndicator({
    super.key,
    required this.message,
    required this.onRetry,
    this.horizontalMargin = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalMargin,
        vertical: 12.0,
      ),
      child: Column(
        children: [
          // Top divider with fade effect
          Container(
            height: 1.0,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.outline.withOpacity(0.1),
                  colorScheme.outline.withOpacity(0.3),
                  colorScheme.outline.withOpacity(0.1),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16.0),

          // Error content
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: colorScheme.errorContainer.withOpacity(0.2),
                width: 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Error icon
                Container(
                  width: 40.0,
                  height: 40.0,
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: colorScheme.error,
                    size: 20.0,
                  ),
                ),
                const SizedBox(width: 12.0),

                // Message and retry button
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unable to load more posts',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        message,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8.0),
                      SizedBox(
                        height: 32.0,
                        child: OutlinedButton(
                          onPressed: onRetry,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 4.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            side: BorderSide(
                              color: colorScheme.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            'Try Again',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8.0),

          // Bottom divider with fade effect
          Container(
            height: 1.0,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.outline.withOpacity(0.1),
                  colorScheme.outline.withOpacity(0.3),
                  colorScheme.outline.withOpacity(0.1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
