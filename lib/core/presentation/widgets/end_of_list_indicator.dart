import 'package:flutter/material.dart';

class EndOfListIndicator extends StatelessWidget {
  final String message;
  final IconData icon;
  final double iconSize;
  final double spacing;

  const EndOfListIndicator({
    super.key,
    this.message = "You've reached the end",
    this.icon = Icons.flag_outlined,
    this.iconSize = 24.0,
    this.spacing = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            SizedBox(height: spacing),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
