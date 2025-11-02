import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/presentation/widgets/empty_state_widget.dart';
import 'package:vlone_blog_app/core/presentation/widgets/error_widget.dart';
import 'package:vlone_blog_app/core/presentation/widgets/loading_indicator.dart';
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
      // Ensure the page both loads notifications and subscribes to unread count.
      bloc.add(const GetNotificationsEvent());
      bloc.add(const NotificationsSubscribeUnreadCountStream());
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
    await context.read<NotificationsBloc>().stream.firstWhere(
      (state) => state is NotificationsLoaded || state is NotificationsError,
    );
  }

  Widget _buildLoadMoreFooter(NotificationsLoaded state) {
    if (state.loadMoreError != null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              'Failed to load more notifications',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => context.read<NotificationsBloc>().add(
                const LoadMoreNotificationsEvent(),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          children: [
            LoadingIndicator(size: 20),
            SizedBox(height: 8),
            Text(
              'Loading more notifications...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
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
          // Ensure the scaffold background extends full-screen
          backgroundColor: Theme.of(context).colorScheme.background,
          appBar: AppBar(
            centerTitle: false,
            // Keep app bar transparent/elevated as desired
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 4,
            leading: isSelectionMode
                ? IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      context.read<NotificationsBloc>().add(
                        const NotificationsExitSelectionMode(),
                      );
                    },
                  )
                : null,
            title: Text(
              isSelectionMode ? '$selectedCount Selected' : 'Notifications',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            actions: [
              if (isSelectionMode)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
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
                                FilledButton(
                                  onPressed: () {
                                    Navigator.of(dialogContext).pop();
                                    context.read<NotificationsBloc>().add(
                                      const NotificationsDeleteSelected(),
                                    );
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.error,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onError,
                                  ),
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
                              const NotificationsMarkAllAsRead(),
                            )
                          : null,
                      child: Text(
                        'Mark All Read',
                        style: TextStyle(
                          color: canMarkAll
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.3),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: Stack(
            children: [
              // Use SafeArea around the content but disable bottom to achieve
              // edge-to-edge content scrolling behind the system navigation bar.
              SafeArea(
                top: false, // AppBar handles top inset
                bottom: false, // <-- FIX: Do not apply bottom system inset here
                child: BlocBuilder<NotificationsBloc, NotificationsState>(
                  builder: (context, state) {
                    if (state is NotificationsLoading ||
                        state is NotificationsInitial) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            LoadingIndicator(size: 32),
                            SizedBox(height: 16),
                            Text(
                              'Loading notifications...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
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
                          message: 'No notifications yet',
                          subMessage:
                              'Notifications will appear here when you get new activity',
                          icon: Icons.notifications_off_outlined,
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: CustomScrollView(
                          controller: _scrollController,
                          // The content will now extend under the system bar
                          slivers: [
                            SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final notification = state.notifications[index];
                                return NotificationListItem(
                                  key: ValueKey(notification.id),
                                  notification: notification,
                                  isSelectionMode: state.isSelectionMode,
                                  isSelected: state.selectedNotificationIds
                                      .contains(notification.id),
                                );
                              }, childCount: state.notifications.length),
                            ),
                            if (state.hasMore)
                              SliverToBoxAdapter(
                                child: _buildLoadMoreFooter(state),
                              ),
                            // Manually add the bottom padding (system inset) to the end
                            // of the scrollable content to prevent the last items
                            // from being covered by the system navigation bar.
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: MediaQuery.of(context).padding.bottom,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return const Center(
                      child: Text('An unexpected error occurred.'),
                    );
                  },
                ),
              ),
              if (isDeleting)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LoadingIndicator(size: 32),
                        SizedBox(height: 16),
                        Text(
                          'Deleting notifications...',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
