import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/routes/slide_transition_page.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/create_post_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/full_media_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/post_details_page.dart';
import 'package:vlone_blog_app/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:vlone_blog_app/features/profile/presentation/pages/profile_page.dart';
import 'package:vlone_blog_app/features/profile/presentation/pages/user_profile_page.dart';
import 'package:vlone_blog_app/core/pages/main_page.dart';
import 'package:vlone_blog_app/features/auth/presentation/pages/login_page.dart';
import 'package:vlone_blog_app/features/auth/presentation/pages/signup_page.dart';
import 'package:vlone_blog_app/features/followers/presentation/pages/followers_page.dart';
import 'package:vlone_blog_app/features/followers/presentation/pages/following_page.dart';
import 'package:vlone_blog_app/features/users/presentation/pages/users_page.dart';
import 'package:vlone_blog_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: Constants.loginRoute,
  routes: [
    GoRoute(
      path: Constants.loginRoute,
      pageBuilder: (context, state) =>
          SlideTransitionPage(key: state.pageKey, child: const LoginPage()),
    ),
    GoRoute(
      path: Constants.signupRoute,
      pageBuilder: (context, state) =>
          SlideTransitionPage(key: state.pageKey, child: const SignupPage()),
    ),
    GoRoute(
      path: Constants.notificationsRoute,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const NotificationsPage(),
      ),
    ),
    GoRoute(
      path: '${Constants.profileRoute}/:userId/edit',
      pageBuilder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return SlideTransitionPage(
          key: state.pageKey,
          child: EditProfilePage(userId: userId),
        );
      },
    ),
    GoRoute(
      path: Constants.createPostRoute,
      pageBuilder: (context, state) {
        return SlideTransitionPage(
          key: state.pageKey,
          child: const CreatePostPage(),
        );
      },
    ),
    GoRoute(
      path: '${Constants.postDetailsRoute}/:postId',
      pageBuilder: (context, state) {
        final postId = state.pathParameters['postId']!;
        final PostEntity? extraPost = state.extra is PostEntity
            ? state.extra as PostEntity
            : null;
        return SlideTransitionPage(
          key: state.pageKey,
          child: PostDetailsPage(postId: postId, post: extraPost),
        );
      },
    ),
    GoRoute(
      path: '/media',
      pageBuilder: (context, state) {
        final PostEntity? post = state.extra is PostEntity
            ? state.extra as PostEntity
            : null;
        if (post == null) {
          return SlideTransitionPage(
            key: state.pageKey,
            child: Scaffold(body: Center(child: Text('Media not found'))),
          );
        }
        return SlideTransitionPage(
          key: state.pageKey,
          child: FullMediaPage(post: post),
        );
      },
    ),
    GoRoute(
      path: '${Constants.followersRoute}/:userId',
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: FollowersPage(userId: state.pathParameters['userId']!),
      ),
    ),
    GoRoute(
      path: '${Constants.followingRoute}/:userId',
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: FollowingPage(userId: state.pathParameters['userId']!),
      ),
    ),
    ShellRoute(
      builder: (context, state, child) {
        return const MainPage();
      },
      routes: [
        GoRoute(
          path: Constants.feedRoute,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SizedBox.shrink()),
        ),
        GoRoute(
          path: Constants.reelsRoute,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SizedBox.shrink()),
        ),
        GoRoute(
          path: Constants.usersRoute,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: UsersPage()),
        ),
        GoRoute(
          path: '${Constants.profileRoute}/me',
          pageBuilder: (context, state) {
            final authState = context.read<AuthBloc>().state;
            if (authState is AuthAuthenticated) {
              final currentUserId = authState.user.id;
              return NoTransitionPage(
                child: ProfilePage(userId: currentUserId),
              );
            } else {
              AppLogger.error('No authenticated user for profile/me route');
              return const NoTransitionPage(
                child: Scaffold(
                  body: Center(
                    child: Text('Unable to load profile. Please log in again.'),
                  ),
                ),
              );
            }
          },
        ),
      ],
    ),
    GoRoute(
      path: '${Constants.profileRoute}/:userId',
      pageBuilder: (context, state) {
        final userId = state.pathParameters['userId']!;
        final authState = context.read<AuthBloc>().state;
        final currentUserId = authState is AuthAuthenticated
            ? authState.user.id
            : null;

        if (currentUserId != null && currentUserId == userId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            GoRouter.of(context).go('${Constants.profileRoute}/me');
          });
          return SlideTransitionPage(
            key: state.pageKey,
            child: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return SlideTransitionPage(
          key: state.pageKey,
          child: UserProfilePage(userId: userId),
        );
      },
    ),
  ],
  errorBuilder: (context, state) {
    AppLogger.error(
      'Router error: ${state.error?.message ?? "Page not found"}',
    );
    return Scaffold(
      body: Center(
        child: Text('Error: ${state.error?.message ?? "Page not found"}'),
      ),
    );
  },

  redirect: (context, state) async {
    AppLogger.info('Router redirect check for path: ${state.uri.path}');

    final authState = context.read<AuthBloc>().state;
    final isLoggedIn = authState is AuthAuthenticated;
    final isAuthRoute =
        state.uri.path == Constants.loginRoute ||
        state.uri.path == Constants.signupRoute;

    if (!isLoggedIn && !isAuthRoute) {
      AppLogger.warning(
        'No auth session found (AuthBloc), redirecting to login',
      );
      return Constants.loginRoute;
    }

    if (isLoggedIn && isAuthRoute) {
      AppLogger.info('User authenticated (AuthBloc), redirecting to feed');
      return Constants.feedRoute;
    }

    AppLogger.info('No redirect needed for path: ${state.uri.path}');
    return null;
  },
);
