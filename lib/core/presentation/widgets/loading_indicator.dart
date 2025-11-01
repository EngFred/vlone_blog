import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final double? size;
  final Color? color;
  final double strokeWidth;

  const LoadingIndicator({
    super.key,
    this.size,
    this.color,
    this.strokeWidth = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    const double defaultSize = 40.0;
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;

    return Center(
      child: SizedBox(
        width: size ?? defaultSize,
        height: size ?? defaultSize,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}
