import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';

class _AuthData {
  final String? userId;
  final String? username;
  final String? profileImageUrl;

  _AuthData({this.userId, this.username, this.profileImageUrl});
}

class UserGreetingTitle extends StatelessWidget {
  const UserGreetingTitle({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  String _getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return '☀️';
    } else if (hour < 17) {
      return '🌤️';
    } else {
      return '🌙';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Use a single BlocSelector to get all needed user data
    return BlocSelector<AuthBloc, AuthState, _AuthData>(
      selector: (state) {
        if (state is AuthAuthenticated) {
          return _AuthData(
            userId: state.user.id, // Now selecting userId
            username: state.user.username,
            profileImageUrl: state.user.profileImageUrl,
          );
        }
        return _AuthData();
      },
      builder: (context, authData) {
        // The userId is crucial for navigation to the profile page
        final String? userId = authData.userId;
        final String? username = authData.username;
        final String? profileImageUrl = authData.profileImageUrl;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (userId != null) {
                    context.go('${Constants.profileRoute}/me');
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary.withOpacity(0.3),
                        colorScheme.secondary.withOpacity(0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: colorScheme.surface,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundImage: profileImageUrl != null
                          ? NetworkImage(profileImageUrl)
                          : null,
                      child: profileImageUrl == null
                          ? Icon(
                              Icons.person,
                              size: 20,
                              color: colorScheme.onSurface.withOpacity(0.6),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _getGreeting(),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getGreetingEmoji(),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  if (username != null)
                    Text(
                      username,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
