import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';

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
    // Get the theme's ColorScheme for theme-aware color selection
    final colorScheme = Theme.of(context).colorScheme;

    return BlocSelector<AuthBloc, AuthState, String?>(
      selector: (state) {
        if (state is AuthAuthenticated) {
          return state.user.username;
        }
        return null;
      },
      builder: (context, username) {
        return BlocSelector<AuthBloc, AuthState, String?>(
          selector: (state) {
            if (state is AuthAuthenticated) {
              return state.user.profileImageUrl;
            }
            return null;
          },
          builder: (context, profileImageUrl) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
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
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _getGreeting(),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              // This is correctly using onSurfaceVariant for less emphasis
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
                            // FIX: Explicitly set text color to onSurface
                            // to ensure it's dark in light mode and light in dark mode.
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
      },
    );
  }
}
