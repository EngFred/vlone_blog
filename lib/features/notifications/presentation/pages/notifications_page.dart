import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/widgets/loading_indicator.dart';
import 'package:vlone_blog_app/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:vlone_blog_app/features/notifications/presentation/widgets/notification_list_item.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    // Ensure the bloc is subscribed to streams when the page is first opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<NotificationsBloc>();

      // Subscribe to the notifications batch stream only.
      AppLogger.info(
        'NotificationsPage: Subscribing to full NotificationsStream.',
      );
      bloc.add(NotificationsSubscribeStream());
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsBloc, NotificationsState>(
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
                    // NOTE: compute "can mark all" from the actual notifications list
                    // rather than relying on a separate unreadCount stream.
                    final bool canMarkAll =
                        state is NotificationsLoaded &&
                        state.notifications.any((n) => !n.isRead);
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
                    // Check the list of notifications itself, not just the state type
                    if (state.notifications.isEmpty) {
                      return const EmptyStateWidget(
                        message: 'You have no notifications yet.',
                        icon: Icons.notifications_off_outlined,
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        // Refresh by re-subscribing
                        final bloc = context.read<NotificationsBloc>();
                        bloc.add(NotificationsSubscribeStream());

                        // Wait for either loaded or error state
                        await bloc.stream.firstWhere(
                          (state) =>
                              state is NotificationsLoaded ||
                              state is NotificationsError,
                        );
                      },
                      child: ListView.builder(
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
                      ),
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
    );
  }
}
