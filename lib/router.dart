import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/create_post_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/feed_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/post_details_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/reels_page.dart';
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
      builder: (context, state) => const CreatePostPage(),
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
          builder: (context, state) => const FeedPage(),
        ),
        GoRoute(
          path: Constants.reelsRoute,
          builder: (context, state) => const ReelsPage(),
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

    // If no session and trying to access protected route, go to login
    if (!isLoggedIn && !isAuthRoute) {
      AppLogger.warning('No session found, redirecting to login');
      return Constants.loginRoute;
    }

    // If has session and trying to access auth pages, redirect to feed
    if (isLoggedIn && isAuthRoute) {
      AppLogger.info('User has session, checking profile access');
      try {
        final result = await sl<GetCurrentUserUseCase>()(NoParams());
        return result.fold(
          (failure) {
            // CRITICAL: Check if it's a network failure
            if (failure is NetworkFailure) {
              AppLogger.warning(
                'Network error during redirect, but session exists. Allowing access to feed: ${failure.message}',
              );
              // User has valid session but no internet - let them access the app
              return Constants.feedRoute;
            }

            // Actual auth failure - redirect to login
            AppLogger.error('Auth failure during redirect: ${failure.message}');
            return Constants.loginRoute;
          },
          (user) {
            AppLogger.info('Redirecting authenticated user ${user.id} to feed');
            return Constants.feedRoute;
          },
        );
      } catch (e, stackTrace) {
        AppLogger.error(
          'Unexpected error during redirect: $e',
          error: e,
          stackTrace: stackTrace,
        );
        // If we have a session, let user proceed despite error
        if (isLoggedIn) {
          AppLogger.info('Session exists despite error, allowing access');
          return Constants.feedRoute;
        }
        return Constants.loginRoute;
      }
    }

    AppLogger.info('No redirect needed for path: ${state.uri.path}');
    return null;
  },
);
