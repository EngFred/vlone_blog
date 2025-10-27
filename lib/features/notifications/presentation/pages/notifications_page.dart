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
    // NOTE:
    // We do not dispatch NotificationsSubscribeStream from the page.
    // The NotificationsBloc should auto-subscribe when created (see DI or bloc constructor).
    return BlocProvider<NotificationsBloc>(
      create: (context) => sl<NotificationsBloc>(),
      child: BlocBuilder<NotificationsBloc, NotificationsState>(
        builder: (context, state) {
          final bool isSelectionMode =
              state is NotificationsLoaded && state.isSelectionMode;
          final int selectedCount = state is NotificationsLoaded
              ? state.selectedNotificationIds.length
              : 0;
          final bool isDeleting =
              state is NotificationsLoaded && state.isDeleting;

          return Scaffold(
            appBar: AppBar(
              centerTitle: false,
              backgroundColor: Theme.of(context).colorScheme.surface,
              iconTheme: IconThemeData(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              leading: isSelectionMode
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        context.read<NotificationsBloc>().add(
                          NotificationsExitSelectionMode(),
                        );
                      },
                    )
                  : null,
              title: Text(
                isSelectionMode ? '$selectedCount Selected' : 'Notifications',
              ),
              actions: [
                if (isSelectionMode)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: selectedCount > 0
                        ? () {
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
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(dialogContext).pop();
                                      context.read<NotificationsBloc>().add(
                                        NotificationsDeleteSelected(),
                                      );
                                    },
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          }
                        : null,
                  )
                else
                  BlocBuilder<NotificationsBloc, NotificationsState>(
                    builder: (context, state) {
                      final bool canMarkAll =
                          state is NotificationsLoaded && state.unreadCount > 0;
                      return TextButton(
                        onPressed: canMarkAll
                            ? () => context.read<NotificationsBloc>().add(
                                NotificationsMarkAllAsRead(),
                              )
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
            body: Stack(
              children: [
                BlocBuilder<NotificationsBloc, NotificationsState>(
                  builder: (context, state) {
                    if (state is NotificationsLoading ||
                        state is NotificationsInitial) {
                      return const LoadingIndicator();
                    }

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

                    if (state is NotificationsLoaded) {
                      if (state.notifications.isEmpty) {
                        return const EmptyStateWidget(
                          message: 'You have no notifications yet.',
                          icon: Icons.notifications_off_outlined,
                        );
                      }

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

                    return const Center(
                      child: Text('An unexpected error occurred.'),
                    );
                  },
                ),
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
