import 'package:flutter/material.dart';

/// A highly reusable function to display a modern, Material 3-styled dialog.
///
/// This dialog is theme-aware, using the app's ColorScheme for a modern look.
/// It supports a dynamic content widget, title, and a list of actions (buttons).
Future<T?> showCustomDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  List<Widget>? actions,
  bool isDismissible = true,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  return showDialog<T>(
    context: context,
    // Using rootNavigator: true ensures the dialog is placed on the top-level
    // navigator, which is crucial for GoRouter compatibility.
    useRootNavigator: true,
    barrierDismissible: isDismissible,
    builder: (BuildContext context) {
      return AlertDialog(
        // Use a high-contrast container color for the dialog background
        // this color adapts perfectly for both Light and Dark themes.
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),

        // --- Title Section ---
        title: Text(
          title,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),

        // --- Content Section ---
        content: content,

        // --- Actions Section (Buttons) ---
        actions: actions,
        actionsPadding: const EdgeInsets.only(right: 16.0, bottom: 16.0),

        // Ensure content and actions are spaced nicely
        titlePadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 8.0),
        contentPadding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 0.0),
      );
    },
  );
}

// --- Example Widget Demonstrating Reusable Buttons ---

/// A factory class to generate standard dialog actions.
class DialogActions {
  /// Creates a standard 'Cancel' button (TextButton style).
  static Widget createCancelButton(
    BuildContext context, {
    required String label,
  }) {
    return TextButton(
      // FIX: Use rootNavigator: true to reliably pop the dialog route
      // and avoid GoRouter conflicts.
      onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
      child: Text(
        label,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  /// Creates a standard 'Primary' action button (FilledButton style).
  static Widget createPrimaryButton(
    BuildContext context, {
    required String label,
    required VoidCallback onPressed,
  }) {
    return FilledButton(
      onPressed: () {
        // FIX: Use rootNavigator: true to reliably pop the dialog route
        Navigator.of(context, rootNavigator: true).pop(true);
        onPressed();
      },
      child: Text(label),
    );
  }
}
