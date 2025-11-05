import 'package:flutter/material.dart';
import 'dart:ui'; // Added for ImageFilter.blur in glassmorphism effect

class SnackbarUtils {
  // --- Core Utility: Builder for consistent, premium SnackBar appearance ---
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
      content: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: backgroundColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(iconData, color: Colors.white),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (action == null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(20),
      duration: Duration(seconds: durationSeconds),
      action: action, // Custom action if provided (e.g., for undo in warnings)
    );
  }

  /// Show error snackbar with premium glassmorphism and optional action.
  static void showError(
    BuildContext context,
    String message, {
    SnackBarAction? action,
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

  /// Show success snackbar with quick dismiss.
  static void showSuccess(
    BuildContext context,
    String message, {
    int durationSeconds = 3,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      _buildSnackBar(
        context: context,
        message: message,
        backgroundColor: Colors.green.shade600,
        iconData: Icons.check_circle_outline,
        action: null,
        durationSeconds: durationSeconds,
      ),
    );
  }

  /// Show info snackbar with clean design.
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

  /// Show warning snackbar with optional action.
  static void showWarning(
    BuildContext context,
    String message, {
    SnackBarAction? action,
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
