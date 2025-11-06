import 'package:flutter/material.dart';

/// Displays a modern, Material 3-styled dialog with flexible content and actions.
///
/// This utility function is theme-aware, utilizing the app's [ColorScheme]
/// for a modern appearance. It ensures proper dialog routing by using the
/// root navigator, preventing potential conflicts in complex routing setups
/// like those managed by GoRouter.
///
/// [context]: The current build context.
/// [title]: The title displayed at the top of the dialog.
/// [content]: The main content widget displayed in the dialog body.
/// [actions]: A list of widgets (typically buttons) to display at the bottom right.
/// [isDismissible]: If true, the dialog can be dismissed by tapping outside the barrier.
///
/// Returns a [Future] that resolves to the result type [T] when the dialog is closed.
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
    // navigator, which is crucial for handling navigation when the dialog is
    // triggered from within a nested route (e.g., a tab or shell route).
    useRootNavigator: true,
    barrierDismissible: isDismissible,
    builder: (BuildContext context) {
      return AlertDialog(
        // Utilizes surfaceContainerHigh for a slightly elevated background color
        // that adapts well to both Light and Dark themes (Material 3 standard).
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),

        // --- Title Section Configuration ---
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
        // Standard padding for actions area.
        actionsPadding: const EdgeInsets.only(right: 16.0, bottom: 16.0),

        // Standardized padding around title and content.
        titlePadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 8.0),
        contentPadding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 0.0),
      );
    },
  );
}

/// A factory class providing static methods to generate standard,
/// pre-styled action buttons for use within the application's custom dialogs.
class DialogActions {
  /// Creates a standard 'Cancel' button using [TextButton] style.
  ///
  /// This button automatically dismisses the dialog and returns `false`.
  static Widget createCancelButton(
    BuildContext context, {
    required String label,
  }) {
    return TextButton(
      /// Using `rootNavigator: true` ensures the dialog route is reliably popped,
      /// regardless of the current navigation stack depth.
      onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
      child: Text(
        label,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  /// Creates a standard 'Primary' action button using [FilledButton] style.
  ///
  /// This button dismisses the dialog, returns `true`, and then executes
  /// the required [onPressed] callback.
  static Widget createPrimaryButton(
    BuildContext context, {
    required String label,
    required VoidCallback onPressed,
  }) {
    return FilledButton(
      onPressed: () {
        /// Reliably popping the dialog route before executing the action.
        Navigator.of(context, rootNavigator: true).pop(true);
        onPressed();
      },
      child: Text(label),
    );
  }
}
