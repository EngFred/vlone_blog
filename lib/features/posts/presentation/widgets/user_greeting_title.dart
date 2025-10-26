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

  @override
  Widget build(BuildContext context) {
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
            return Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: profileImageUrl != null
                      ? NetworkImage(profileImageUrl)
                      : null,
                  child: profileImageUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getGreeting()},',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (username != null)
                      Text(
                        username,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}
