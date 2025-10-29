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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<NotificationsBloc>();
      bloc.add(const GetNotificationsEvent());
      // bloc.add(const NotificationsSubscribeUnreadCountStream());
      AppLogger.info(
        'NotificationsPage: Loaded initial notifications and subscribed to unread count.',
      );
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        final state = context.read<NotificationsBloc>().state;
        if (state is NotificationsLoaded &&
            state.hasMore &&
            !state.isLoadingMore) {
          context.read<NotificationsBloc>().add(
            const LoadMoreNotificationsEvent(),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    context.read<NotificationsBloc>().add(const RefreshNotificationsEvent());

    // Wait for the refresh to complete (loaded or error)
    await context.read<NotificationsBloc>().stream.firstWhere(
      (state) => state is NotificationsLoaded || state is NotificationsError,
    );
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
                        const NotificationsExitSelectionMode(),
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
                                      const NotificationsDeleteSelected(),
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
                        state is NotificationsLoaded &&
                        state.notifications.any((n) => !n.isRead);
                    return TextButton(
                      onPressed: canMarkAll
                          ? () => context.read<NotificationsBloc>().add(
                              const NotificationsMarkAllAsRead(),
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
                    return const Center(child: LoadingIndicator());
                  }

                  if (state is NotificationsError) {
                    return CustomErrorWidget(
                      message: state.message,
                      onRetry: () {
                        context.read<NotificationsBloc>().add(
                          const GetNotificationsEvent(),
                        );
                      },
                    );
                  }

                  if (state is NotificationsLoaded) {
                    if (state.notifications.isEmpty && !state.hasMore) {
                      return const EmptyStateWidget(
                        message: 'You have no notifications yet.',
                        icon: Icons.notifications_off_outlined,
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount:
                            state.notifications.length +
                            (state.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == state.notifications.length) {
                            // Load more footer
                            if (state.loadMoreError != null) {
                              return ListTile(
                                title: Text(
                                  'Error loading more: ${state.loadMoreError}',
                                ),
                                trailing: TextButton(
                                  onPressed: () => context
                                      .read<NotificationsBloc>()
                                      .add(const LoadMoreNotificationsEvent()),
                                  child: const Text('Retry'),
                                ),
                              );
                            }
                            if (state.isLoadingMore) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: LoadingIndicator()),
                              );
                            }
                            return const SizedBox.shrink();
                          }

                          final notification = state.notifications[index];
                          return NotificationListItem(
                            key: ValueKey(notification.id),
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
                  child: const Center(child: LoadingIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }
}
