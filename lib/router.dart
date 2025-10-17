import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/features/auth/presentation/pages/login_page.dart';
import 'package:vlone_blog_app/features/auth/presentation/pages/signup_page.dart';
import 'package:vlone_blog_app/features/comments/presentation/pages/comments_page.dart';
import 'package:vlone_blog_app/features/favorites/presentation/pages/favorites_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/create_post_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/feed_page.dart';
import 'package:vlone_blog_app/features/profile/presentation/pages/profile_page.dart';
import 'package:vlone_blog_app/features/followers/presentation/pages/followers_page.dart';
import 'package:vlone_blog_app/features/followers/presentation/pages/following_page.dart';
import 'package:flutter/material.dart';

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
      path: Constants.feedRoute,
      builder: (context, state) => const FeedPage(),
    ),
    GoRoute(
      path: '${Constants.profileRoute}/:userId',
      builder: (context, state) =>
          ProfilePage(userId: state.pathParameters['userId']!),
    ),
    GoRoute(
      path: '/create-post',
      builder: (context, state) => const CreatePostPage(),
    ),
    GoRoute(
      path: '${Constants.commentsRoute}/:postId',
      builder: (context, state) =>
          CommentsPage(postId: state.pathParameters['postId']!),
    ),
    GoRoute(
      path: Constants.favoritesRoute,
      builder: (context, state) => const FavoritesPage(),
    ),
    GoRoute(
      path: '${Constants.followersRoute}/:userId',
      builder: (context, state) =>
          FollowersPage(userId: state.pathParameters['userId']!),
    ),
    GoRoute(
      path: '${Constants.followingRoute}/:userId',
      builder: (context, state) =>
          FollowingPage(userId: state.pathParameters['userId']!),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Error: ${state.error?.message ?? "Page not found"}'),
    ),
  ),
  redirect: (context, state) async {
    final supabase = sl<SupabaseClient>();
    final session = supabase.auth.currentSession;
    final isLoggedIn = session != null;
    final isAuthRoute =
        state.uri.path == Constants.loginRoute ||
        state.uri.path == Constants.signupRoute;

    if (!isLoggedIn && !isAuthRoute) {
      return Constants.loginRoute;
    }
    if (isLoggedIn && isAuthRoute) {
      return Constants.feedRoute;
    }
    return null;
  },
);
