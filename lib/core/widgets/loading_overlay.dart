import 'package:flutter/material.dart';

/// A full-screen, semi-transparent modal overlay used to indicate a loading or saving process.
class SavingLoadingOverlay extends StatelessWidget {
  final String message;
  final Color? indicatorColor;

  const SavingLoadingOverlay({
    super.key,
    this.message = 'Processing...',
    this.indicatorColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = indicatorColor ?? theme.colorScheme.primary;

    return Container(
      // Fills the entire screen/parent Stack
      width: double.infinity,
      height: double.infinity,
      color: Colors.black54, // Dark transparent overlay
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Loading Indicator (Moved to the top)
              CircularProgressIndicator(color: color),

              // 2. Spacing
              const SizedBox(height: 20),

              // 3. Message Text (Moved to the bottom)
              Text(
                message,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
