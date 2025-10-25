import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/features/notifications/presentation/bloc/notifications_bloc.dart';

/// A reusable widget that displays a notification icon with an unread count badge.
/// It automatically listens to the NotificationsBloc for state updates.
class NotificationIconWithBadge extends StatelessWidget {
  const NotificationIconWithBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsBloc, NotificationsState>(
      builder: (context, state) {
        int unreadCount = 0;

        if (state is NotificationsLoaded) {
          unreadCount = state.unreadCount;
        }

        // Cap display at 99+
        final badgeText = unreadCount > 99 ? '99+' : unreadCount.toString();
        final iconColor = Theme.of(context).colorScheme.onSurface;
        final primaryColor = Theme.of(context).colorScheme.primary;
        final onPrimaryColor = Theme.of(context).colorScheme.onPrimary;

        return Padding(
          padding: const EdgeInsets.only(
            right: 4.0,
          ), // Adjust padding for a better look in AppBar
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              // Navigate to the notifications page on tap
              context.push(Constants.notificationsRoute);
            },
            child: Stack(
              clipBehavior: Clip
                  .none, // Allows the badge to extend outside the Stack bounds
              alignment: Alignment.center,
              children: [
                // 1. The main icon
                Container(
                  padding: const EdgeInsets.all(
                    8.0,
                  ), // Gives the InkWell a larger tap area
                  child: Icon(
                    // Change icon style based on unread count
                    unreadCount > 0
                        ? Icons.notifications
                        : Icons.notifications_none,
                    color: iconColor,
                  ),
                ),

                // 2. The badge positioned at the top right
                if (unreadCount > 0)
                  Positioned(
                    right:
                        0, // Positioned at the right edge of the InkWell area
                    top: 0, // Positioned at the top edge of the InkWell area
                    child: Semantics(
                      label: '$unreadCount unread notifications',
                      child: Container(
                        padding: const EdgeInsets.all(
                          4,
                        ), // Slightly smaller padding for a nicer badge
                        constraints: const BoxConstraints(
                          minWidth: 16, // Minimum size for a small dot badge
                          minHeight: 16,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape
                              .circle, // Use circular shape for a more modern look
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            badgeText,
                            style:
                                Theme.of(
                                  context,
                                ).textTheme.labelSmall?.copyWith(
                                  color: onPrimaryColor,
                                  fontSize: unreadCount > 9
                                      ? 8
                                      : 10, // Smaller font for '99+'
                                  fontWeight: FontWeight.bold,
                                ) ??
                                TextStyle(
                                  color: onPrimaryColor,
                                  fontSize: unreadCount > 9 ? 8 : 10,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
