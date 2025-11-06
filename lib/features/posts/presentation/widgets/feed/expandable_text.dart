import 'package:flutter/material.dart';

/// A simple expandable text widget that shows [collapsedMaxLines] by default
/// and reveals the full text when the user taps "Read more". This implementation
/// computes overflow synchronously inside the build using a TextPainter and *does
/// not* call setState during layout, avoiding "setState() called during build"
/// errors. The only time we call setState is when the user taps the toggle.
class ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle? textStyle;
  final int collapsedMaxLines;
  final String readMoreLabel;
  final String readLessLabel;

  const ExpandableText({
    super.key,
    required this.text,
    this.textStyle,
    this.collapsedMaxLines = 3,
    this.readMoreLabel = 'Read more',
    this.readLessLabel = 'Show less',
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle =
        widget.textStyle ?? Theme.of(context).textTheme.bodyLarge;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Synchronously measure whether the text will exceed the collapsed max
        // lines for the current constraints. This avoids calling setState during
        // the build/layout phase.
        final textSpan = TextSpan(text: widget.text, style: effectiveStyle);
        final tp = TextPainter(
          text: textSpan,
          textDirection: Directionality.of(context),
          maxLines: widget.collapsedMaxLines,
          textScaleFactor: MediaQuery.of(context).textScaleFactor,
        );
        tp.layout(maxWidth: constraints.maxWidth);
        final isOverflowing = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: effectiveStyle,
              maxLines: _expanded ? null : widget.collapsedMaxLines,
              overflow: TextOverflow.fade,
            ),
            if (isOverflowing)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? widget.readLessLabel : widget.readMoreLabel,
                    style: (effectiveStyle ?? const TextStyle()).copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
