// Updated router.dart with optimizations:
// - No major changes needed, as it's already efficient with sync session checks.
// - Added comment for clarity on performance.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/create_post_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/post_details_page.dart';
import 'package:vlone_blog_app/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:vlone_blog_app/features/profile/presentation/pages/profile_page.dart';
import 'package:vlone_blog_app/core/pages/main_page.dart';
import 'package:vlone_blog_app/features/auth/presentation/pages/login_page.dart';
import 'package:vlone_blog_app/features/auth/presentation/pages/signup_page.dart';
import 'package:vlone_blog_app/features/followers/presentation/pages/followers_page.dart';
import 'package:vlone_blog_app/features/followers/presentation/pages/following_page.dart';
import 'package:vlone_blog_app/features/users/presentation/pages/users_page.dart';
import 'package:vlone_blog_app/features/notifications/presentation/pages/notifications_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: Constants.loginRoute,
  routes: [
    GoRoute(
      path: Constants.loginRoute,
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: Constants.signupRoute,
      builder: (context, state) => const SignupPage(),
    ),
    GoRoute(
      path: Constants.notificationsRoute,
      builder: (context, state) => const NotificationsPage(),
    ),
    GoRoute(
      path: '${Constants.profileRoute}/:userId/edit',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return EditProfilePage(userId: userId);
      },
    ),
    GoRoute(
      path: Constants.createPostRoute,
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return CreatePostPage(userId: userId);
      },
    ),
    GoRoute(
      path: '${Constants.postDetailsRoute}/:postId',
      builder: (context, state) {
        final postId = state.pathParameters['postId']!;
        final PostEntity? extraPost = state.extra is PostEntity
            ? state.extra as PostEntity
            : null;
        return PostDetailsPage(postId: postId, post: extraPost);
      },
    ),
    GoRoute(
      path: Constants.followersRoute + '/:userId',
      builder: (context, state) =>
          FollowersPage(userId: state.pathParameters['userId']!),
    ),
    GoRoute(
      path: Constants.followingRoute + '/:userId',
      builder: (context, state) =>
          FollowingPage(userId: state.pathParameters['userId']!),
    ),
    ShellRoute(
      builder: (context, state, child) {
        return const MainPage();
      },
      routes: [
        GoRoute(
          path: Constants.feedRoute,
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: Constants.reelsRoute,
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: Constants.usersRoute,
          builder: (context, state) => const UsersPage(),
        ),
        GoRoute(
          path: Constants.profileRoute + '/:userId',
          builder: (context, state) =>
              ProfilePage(userId: state.pathParameters['userId']!),
        ),
      ],
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
    final supabase = sl<SupabaseClient>();
    final session = supabase.auth.currentSession;
    final isLoggedIn = session != null;
    final isAuthRoute =
        state.uri.path == Constants.loginRoute ||
        state.uri.path == Constants.signupRoute;

    // ✅ OPTIMIZED: Simplified redirect logic
    // No longer fetches user profile here - AuthBloc already did that
    // This eliminates one redundant profile fetch during startup

    // If no session and trying to access protected route, go to login
    if (!isLoggedIn && !isAuthRoute) {
      AppLogger.warning('No session found, redirecting to login');
      return Constants.loginRoute;
    }

    // If has session and trying to access auth pages, redirect to feed
    // ✅ PERFORMANCE: Trust the session - don't re-fetch user profile
    // AuthBloc already validated the user during CheckAuthStatusEvent
    if (isLoggedIn && isAuthRoute) {
      AppLogger.info('User has valid session, redirecting to feed');
      return Constants.feedRoute;
    }

    AppLogger.info('No redirect needed for path: ${state.uri.path}');
    return null;
  },
);
