import 'package:flutter/material.dart';

/// A full-screen, semi-transparent modal overlay used to indicate a loading or saving process.
/// - If [percent] is null: shows an indeterminate spinner and [message].
/// - If [percent] is provided: shows a single determinate circular indicator and displays
///   both the message and the percentage combined in one text line (e.g. "Compressing video... 25%").
class SavingLoadingOverlay extends StatelessWidget {
  final String message;

  /// Optional 0..100 percent. If null, an indeterminate spinner is shown.
  final double? percent;
  final Color? indicatorColor;

  const SavingLoadingOverlay({
    super.key,
    this.message = 'Processing...',
    this.percent,
    this.indicatorColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = indicatorColor ?? theme.colorScheme.primary;
    final bool showPercent = percent != null;
    final double shownPercent = (percent ?? 0.0).clamp(0.0, 100.0);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black54, // dark translucent backdrop
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circular progress indicator (same size in both cases)
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: showPercent
                      ? (shownPercent / 100.0).clamp(0.0, 1.0)
                      : null,
                  strokeWidth: 7,
                  color: color,
                  backgroundColor: Colors.white12,
                ),
              ),

              const SizedBox(height: 16),

              // Combined message + percent (e.g. "Compressing video... 25%")
              Text(
                showPercent ? '$message ${shownPercent.round()}%' : message,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
