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
import 'package:vlone_blog_app/features/profile/presentation/pages/user_profile_page.dart';
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
        // ✅ Bottom nav profile page route
        // "me" is just a route identifier, we resolve it to actual userId
        GoRoute(
          path: '${Constants.profileRoute}/me',
          builder: (context, state) {
            final supabase = sl<SupabaseClient>();
            final currentUserId = supabase.auth.currentUser?.id;
            if (currentUserId == null) {
              AppLogger.error('No current user found for profile/me route');
              return const Scaffold(
                body: Center(
                  child: Text('Unable to load profile. Please log in again.'),
                ),
              );
            }
            // ✅ Pass the actual userId, not "me"
            return ProfilePage(userId: currentUserId);
          },
        ),
      ],
    ),
    // ✅ Standalone user profile route (outside ShellRoute)
    // This handles viewing other users' profiles
    GoRoute(
      path: '${Constants.profileRoute}/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        final supabase = sl<SupabaseClient>();
        final currentUserId = supabase.auth.currentUser?.id;

        // If viewing own profile from a direct link, redirect to /profile/me for bottom nav
        if (currentUserId != null && currentUserId == userId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            GoRouter.of(context).go('${Constants.profileRoute}/me');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return UserProfilePage(userId: userId);
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
      AppLogger.info('User has valid session, redirecting to feed');
      return Constants.feedRoute;
    }

    AppLogger.info('No redirect needed for path: ${state.uri.path}');
    return null;
  },
);
