import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final String message;
  final String? subMessage;
  final IconData icon;
  final VoidCallback? onRetry;
  final String? actionText;
  final Color? iconColor;
  final Color? backgroundColor;

  const EmptyStateWidget({
    super.key,
    required this.message,
    required this.icon,
    this.subMessage,
    this.onRetry,
    this.actionText,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor =
        iconColor ?? theme.colorScheme.onSurface.withOpacity(0.6);
    final effectiveBackgroundColor =
        backgroundColor ?? theme.colorScheme.surface;

    return Container(
      color: effectiveBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                    0.3,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48.0, color: effectiveIconColor),
              ),
              const SizedBox(height: 24.0),
              Text(
                message,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              if (subMessage != null) ...[
                const SizedBox(height: 8.0),
                Text(
                  subMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (onRetry != null && actionText != null) ...[
                const SizedBox(height: 32.0),
                FilledButton.tonal(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 12.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        actionText!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
