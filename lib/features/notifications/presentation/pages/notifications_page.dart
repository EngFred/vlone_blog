import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:vlone_blog_app/features/notifications/presentation/widgets/notification_list_item.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          sl<NotificationsBloc>()..add(NotificationsSubscribeStream()),
      child: BlocBuilder<NotificationsBloc, NotificationsState>(
        builder: (context, state) {
          // Determine state variables from the loaded state
          final bool isSelectionMode =
              state is NotificationsLoaded && state.isSelectionMode;
          final int selectedCount = state is NotificationsLoaded
              ? state.selectedNotificationIds.length
              : 0;
          final bool isDeleting =
              state is NotificationsLoaded && state.isDeleting;

          return Scaffold(
            appBar: AppBar(
              // Show context-aware AppBar
              leading: isSelectionMode
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        context.read<NotificationsBloc>().add(
                          NotificationsExitSelectionMode(),
                        );
                      },
                    )
                  : null, // Use default back button
              title: Text(
                isSelectionMode ? '$selectedCount Selected' : 'Notifications',
              ),
              actions: [
                if (isSelectionMode)
                  // Show Delete button in selection mode
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: selectedCount > 0
                        ? () {
                            // --- Show confirmation dialog ---
                            showDialog(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: Text(
                                  'Delete $selectedCount notification${selectedCount > 1 ? 's' : ''}?',
                                ),
                                content: const Text(
                                  'This action cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    child: const Text('Cancel'),
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                  ),
                                  TextButton(
                                    child: const Text('Delete'),
                                    onPressed: () {
                                      Navigator.of(dialogContext).pop();
                                      context.read<NotificationsBloc>().add(
                                        NotificationsDeleteSelected(),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          }
                        : null,
                  )
                else
                  // Show Mark All Read button in normal mode
                  BlocBuilder<NotificationsBloc, NotificationsState>(
                    builder: (context, state) {
                      final bool canMarkAll =
                          state is NotificationsLoaded && state.unreadCount > 0;

                      return TextButton(
                        onPressed: canMarkAll
                            ? () {
                                context.read<NotificationsBloc>().add(
                                  NotificationsMarkAllAsRead(),
                                );
                              }
                            : null,
                        child: Text(
                          'Mark All Read',
                          style: TextStyle(
                            color: canMarkAll
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            // Stack to show loading indicator over the list
            body: Stack(
              children: [
                BlocBuilder<NotificationsBloc, NotificationsState>(
                  builder: (context, state) {
                    // Loading State
                    if (state is NotificationsLoading ||
                        state is NotificationsInitial) {
                      return const LoadingIndicator();
                    }

                    // Error State
                    if (state is NotificationsError) {
                      return CustomErrorWidget(
                        message: state.message,
                        onRetry: () {
                          context.read<NotificationsBloc>().add(
                            NotificationsSubscribeStream(),
                          );
                        },
                      );
                    }

                    // Loaded State
                    if (state is NotificationsLoaded) {
                      // Empty State
                      if (state.notifications.isEmpty) {
                        return const EmptyStateWidget(
                          message: 'You have no notifications yet.',
                          icon: Icons.notifications_off_outlined,
                        );
                      }

                      // List of Notifications
                      return ListView.builder(
                        itemCount: state.notifications.length,
                        itemBuilder: (context, index) {
                          final notification = state.notifications[index];
                          return NotificationListItem(
                            notification: notification,
                            isSelectionMode: state.isSelectionMode,
                            isSelected: state.selectedNotificationIds.contains(
                              notification.id,
                            ),
                          );
                        },
                      );
                    }

                    // Fallback
                    return const Center(
                      child: Text('An unexpected error occurred.'),
                    );
                  },
                ),

                // Deleting Overlay
                if (isDeleting)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const LoadingIndicator(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
