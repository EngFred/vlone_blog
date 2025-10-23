import 'package:flutter/material.dart';

class MediaPlaceholder extends StatelessWidget {
  final VoidCallback onTap;
  const MediaPlaceholder({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          // Use a subtle, theme-aware container color
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          // Use the theme's outline color for the border
          border: Border.all(color: theme.colorScheme.outline, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Use a theme-aware "onSurface" color for text/icons
            Icon(
              Icons.add_a_photo_outlined,
              size: 50,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'Add photo or video',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
