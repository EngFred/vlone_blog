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
      create: (context) => sl<NotificationsBloc>()
        ..add(NotificationsSubscribeStream()), // Start subscribing immediately
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            // Button to mark all as read
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
        body: BlocBuilder<NotificationsBloc, NotificationsState>(
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
                  return NotificationListItem(notification: notification);
                },
              );
            }

            // Fallback for any other unhandled state
            return const Center(child: Text('An unexpected error occurred.'));
          },
        ),
      ),
    );
  }
}
