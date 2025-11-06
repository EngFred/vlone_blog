import 'package:flutter/material.dart';

class EndOfReelsIndicator extends StatelessWidget {
  final String message;
  final IconData icon;
  final double iconSize;
  final double spacing;

  const EndOfReelsIndicator({
    super.key,
    this.message = "You've reached the end",
    this.icon = Icons.flag_outlined,
    this.iconSize = 48.0,
    this.spacing = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize, color: Colors.white.withOpacity(0.6)),
            SizedBox(height: spacing),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16.0,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing),
            Text(
              'Swipe down to refresh',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
