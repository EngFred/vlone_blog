import 'package:flutter/material.dart';

class SnackbarUtils {
  // --- Core Utility: Builder for consistent SnackBar appearance ---
  static SnackBar _buildSnackBar({
    required BuildContext context,
    required String message,
    required Color backgroundColor,
    required IconData iconData,
    SnackBarAction? action,
    int durationSeconds = 3,
  }) {
    // Hide any previous SnackBar to prevent stacking
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    return SnackBar(
      content: Row(
        children: [
          Icon(iconData, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: durationSeconds),
      action:
          action ??
          SnackBarAction(
            label: 'DISMISS',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
    );
  }

  /// Show error snackbar with white text and optional action.
  static void showError(
    BuildContext context,
    String message, {
    SnackBarAction? action, // Added optional action
    int durationSeconds = 4,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      _buildSnackBar(
        context: context,
        message: message,
        backgroundColor: Colors.red.shade600,
        iconData: Icons.error_outline,
        action: action,
        durationSeconds: durationSeconds,
      ),
    );
  }

  /// Show success snackbar with white text.
  static void showSuccess(
    BuildContext context,
    String message, {
    int durationSeconds = 3,
  }) {
    if (!context.mounted) return;

    // Success messages usually don't need a persistent action button
    ScaffoldMessenger.of(context).showSnackBar(
      _buildSnackBar(
        context: context,
        message: message,
        backgroundColor: Colors.green.shade600,
        iconData: Icons.check_circle_outline,
        // Using a short duration and no persistent action for a smooth UX
        action: null,
        durationSeconds: durationSeconds,
      ),
    );
  }

  /// Show info snackbar with white text.
  static void showInfo(
    BuildContext context,
    String message, {
    int durationSeconds = 3,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      _buildSnackBar(
        context: context,
        message: message,
        backgroundColor: Colors.blue.shade600,
        iconData: Icons.info_outline,
        action: null,
        durationSeconds: durationSeconds,
      ),
    );
  }

  /// Show warning snackbar with white text and optional action.
  static void showWarning(
    BuildContext context,
    String message, {
    SnackBarAction? action, // Added optional action
    int durationSeconds = 5,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      _buildSnackBar(
        context: context,
        message: message,
        backgroundColor: Colors.orange.shade700,
        iconData: Icons.warning_amber_outlined,
        action: action,
        durationSeconds: durationSeconds,
      ),
    );
  }
}
