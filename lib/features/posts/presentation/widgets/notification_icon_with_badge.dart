import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/features/notifications/presentation/bloc/notifications_bloc.dart';

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

        final badgeText = unreadCount > 99 ? '99+' : unreadCount.toString();
        final iconColor = Theme.of(context).colorScheme.onSurface;
        final primaryColor = Theme.of(context).colorScheme.primary;
        final onPrimaryColor = Theme.of(context).colorScheme.onPrimary;

        return Container(
          margin: const EdgeInsets.only(right: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                context.push(Constants.notificationsRoute);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      unreadCount > 0
                          ? Icons.notifications_rounded
                          : Icons.notifications_none_rounded,
                      color: iconColor,
                      size: 24,
                    ),

                    // Modern badge design
                    if (unreadCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: unreadCount > 9 ? 4 : 6,
                            vertical: 2,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.4),
                                blurRadius: 6,
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
                                    fontSize: unreadCount > 9 ? 8 : 10,
                                    fontWeight: FontWeight.w800,
                                    height: 1.0,
                                  ) ??
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    height: 1.0,
                                  ),
                            ),
                          ),
                        ),
                      ),

                    // Subtle pulse animation for unread notifications
                    if (unreadCount > 0)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withOpacity(0.6),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
