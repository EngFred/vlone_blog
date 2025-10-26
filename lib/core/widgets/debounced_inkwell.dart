import 'package:flutter/material.dart';
import 'package:vlone_blog_app/core/utils/debouncer.dart';

/// Like InkWell but debounces onTap by [duration] using [actionKey] as identifier.
class DebouncedInkWell extends StatelessWidget {
  final Widget child;
  final String actionKey;
  final Duration duration;
  final VoidCallback onTap;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  const DebouncedInkWell({
    super.key,
    required this.child,
    required this.actionKey,
    required this.onTap,
    this.duration = const Duration(milliseconds: 300),
    this.borderRadius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Debouncer.instance.debounce(actionKey, duration, onTap),
      borderRadius: borderRadius,
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
  }
}
