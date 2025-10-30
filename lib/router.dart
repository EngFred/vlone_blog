import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/routes/slide_transition_page.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/create_post_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/feed_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/full_media_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/post_details_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/reels_page.dart';
import 'package:vlone_blog_app/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:vlone_blog_app/features/profile/presentation/pages/profile_page.dart';
import 'package:vlone_blog_app/features/profile/presentation/pages/user_profile_page.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/user_posts/user_posts_bloc.dart';
import 'package:vlone_blog_app/core/pages/main_page.dart';
import 'package:vlone_blog_app/features/auth/presentation/pages/login_page.dart';
import 'package:vlone_blog_app/features/auth/presentation/pages/signup_page.dart';
import 'package:vlone_blog_app/features/followers/presentation/pages/followers_page.dart';
import 'package:vlone_blog_app/features/followers/presentation/pages/following_page.dart';
import 'package:vlone_blog_app/features/users/presentation/pages/users_page.dart';
import 'package:vlone_blog_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';

// Add these at the top of main.dart (global keys for branches)
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorFeedKey = GlobalKey<NavigatorState>(debugLabel: 'feed');
final _shellNavigatorReelsKey = GlobalKey<NavigatorState>(debugLabel: 'reels');
final _shellNavigatorUsersKey = GlobalKey<NavigatorState>(debugLabel: 'users');
final _shellNavigatorProfileKey = GlobalKey<NavigatorState>(
  debugLabel: 'profile',
);

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: Constants.loginRoute,
  routes: [
    // --- Authentication Routes ---
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
    // --- Secondary Routes (Not in Main Navigation Shell) ---
    GoRoute(
      path: Constants.notificationsRoute,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const NotificationsPage(),
      ),
    ),
    GoRoute(
      path: '${Constants.profileRoute}/:userId/edit',
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: EditProfilePage(userId: state.pathParameters['userId']!),
      ),
    ),
    GoRoute(
      path: Constants.createPostRoute,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const CreatePostPage(),
      ),
    ),
    GoRoute(
      path: '${Constants.postDetailsRoute}/:postId',
      pageBuilder: (context, state) {
        final postId = state.pathParameters['postId']!;
        // Default values
        PostEntity? extraPost;
        String? highlightCommentId;
        String? parentCommentId;
        final extra = state.extra;
        if (extra is Map<String, dynamic>) {
          extraPost = extra['post'] as PostEntity?;
          highlightCommentId = extra['highlightCommentId'] as String?;
          parentCommentId = extra['parentCommentId'] as String?;
        } else if (extra is PostEntity) {
          // Handle legacy case where only PostEntity was passed
          extraPost = extra;
        }
        // Pass highlight IDs to PostDetailsPage
        return SlideTransitionPage(
          key: state.pageKey,
          child: PostDetailsPage(
            postId: postId,
            post: extraPost,
            highlightCommentId: highlightCommentId,
            parentCommentId: parentCommentId,
          ),
        );
      },
    ),
    GoRoute(
      path: '/media',
      pageBuilder: (context, state) {
        PostEntity? post;
        String? heroTag;
        final extra = state.extra;
        if (extra is PostEntity) {
          post = extra;
          heroTag = null;
        } else if (extra is Map) {
          final potentialPost = extra['post'];
          if (potentialPost is PostEntity) {
            post = potentialPost;
            final potentialTag = extra['heroTag'];
            if (potentialTag is String) heroTag = potentialTag;
          } else {
            AppLogger.info(
              'Router /media: extra Map provided but missing "post" key or wrong type: ${extra.runtimeType}',
            );
          }
        } else if (extra != null) {
          AppLogger.info(
            'Router /media: unrecognized extra type: ${extra.runtimeType}',
          );
        }
        if (post == null) {
          return SlideTransitionPage(
            key: state.pageKey,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Media'),
                backgroundColor: Theme.of(context).colorScheme.surface,
              ),
              body: const Center(child: Text('Media not found')),
            ),
          );
        }
        return SlideTransitionPage(
          key: state.pageKey,
          child: FullMediaPage(post: post, heroTag: heroTag),
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
    // --- Main Stateful Shell Route for Tab Navigation ---
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainPage(navigationShell: navigationShell);
      },
      branches: [
        // Tab 1: Feed/Home
        StatefulShellBranch(
          navigatorKey: _shellNavigatorFeedKey,
          routes: [
            GoRoute(
              path: Constants.feedRoute,
              builder: (context, state) => const FeedPage(),
            ),
          ],
        ),
        // Tab 2: Reels
        StatefulShellBranch(
          navigatorKey: _shellNavigatorReelsKey,
          routes: [
            GoRoute(
              path: Constants.reelsRoute,
              builder: (context, state) => const ReelsPage(),
            ),
          ],
        ),
        // Tab 3: Users/Search
        StatefulShellBranch(
          navigatorKey: _shellNavigatorUsersKey,
          routes: [
            GoRoute(
              path: Constants.usersRoute,
              builder: (context, state) => const UsersPage(),
            ),
          ],
        ),
        // Tab 4: My Profile
        StatefulShellBranch(
          navigatorKey: _shellNavigatorProfileKey,
          routes: [
            GoRoute(
              path: '${Constants.profileRoute}/me',
              builder: (context, state) => const ProfilePage(),
            ),
          ],
        ),
      ],
    ),
    // --- Other User's Profile Page (outside shell) ---
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
          // 2. USE MultiBlocProvider with the specialized BLoCs
          child: MultiBlocProvider(
            providers: [
              // Factory creates fresh, isolated instance for this UserProfilePage
              BlocProvider<ProfileBloc>(create: (context) => sl<ProfileBloc>()),
              // ✅ FIX: Use the dedicated UserPostsBloc for this profile view
              BlocProvider<UserPostsBloc>(
                create: (context) => sl<UserPostsBloc>(),
              ),
            ],
            child: UserProfilePage(userId: userId),
          ),
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
