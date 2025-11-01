import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart' as di;
import 'package:vlone_blog_app/core/routes/slide_transition_page.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/auth/presentation/pages/login_page.dart';
import 'package:vlone_blog_app/features/auth/presentation/pages/signup_page.dart';
import 'package:vlone_blog_app/core/pages/main_page.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/feed/feed_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/reels/reels_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/user_posts/user_posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/create_post_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/feed_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/full_media_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/post_details_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/reels_page.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:vlone_blog_app/features/profile/presentation/pages/profile_page.dart';
import 'package:vlone_blog_app/features/profile/presentation/pages/user_profile_page.dart';
import 'package:vlone_blog_app/features/followers/presentation/bloc/followers_bloc.dart';
import 'package:vlone_blog_app/features/followers/presentation/pages/followers_page.dart';
import 'package:vlone_blog_app/features/followers/presentation/pages/following_page.dart';
import 'package:vlone_blog_app/features/users/presentation/bloc/users_bloc.dart';
import 'package:vlone_blog_app/features/users/presentation/pages/users_page.dart';
import 'package:vlone_blog_app/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:vlone_blog_app/features/notifications/presentation/pages/notifications_page.dart';

// Global keys for branches
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
        // NotificationsBloc is provided here for the page itself (e.g. to load data)
        child: BlocProvider<NotificationsBloc>(
          create: (_) => di.sl<NotificationsBloc>(),
          child: const NotificationsPage(),
        ),
      ),
    ),
    GoRoute(
      path: Constants.createPostRoute,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        // PostActionsBloc is Global
        child: const CreatePostPage(),
      ),
    ),
    GoRoute(
      path: '${Constants.postDetailsRoute}/:postId',
      pageBuilder: (context, state) {
        final postId = state.pathParameters['postId']!;
        PostEntity? extraPost;
        String? highlightCommentId;
        String? parentCommentId;

        final extra = state.extra;
        if (extra is Map<String, dynamic>) {
          extraPost = extra['post'] as PostEntity?;
          highlightCommentId = extra['highlightCommentId'] as String?;
          parentCommentId = extra['parentCommentId'] as String?;
        } else if (extra is PostEntity) {
          extraPost = extra;
        }

        return SlideTransitionPage(
          key: state.pageKey,
          // All BLoCs (PostActions, Likes, Comments, Favorites) are now global.
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

        // 💡 FIX: Safely extract PostEntity and heroTag from state.extra
        final extra = state.extra;
        if (extra is Map<String, dynamic>) {
          post = extra['post'] as PostEntity?;
          heroTag = extra['heroTag'] as String?;
        } else if (extra is PostEntity) {
          post = extra;
        }

        // 💡 FIX: Handle null post object safely before using it
        if (post == null) {
          return SlideTransitionPage(
            key: state.pageKey,
            child: const Scaffold(
              body: Center(
                child: Text(
                  'Error: Media data not found.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        }

        return SlideTransitionPage(
          key: state.pageKey,
          child: FullMediaPage(
            post: post, // Removed the crashing '!'
            heroTag: heroTag,
          ),
        );
      },
    ),
    GoRoute(
      path: '${Constants.followersRoute}/:userId',
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        // Provide FollowersBloc for FollowersPage
        child: BlocProvider<FollowersBloc>(
          create: (_) => di.sl<FollowersBloc>(),
          child: FollowersPage(userId: state.pathParameters['userId']!),
        ),
      ),
    ),
    GoRoute(
      path: '${Constants.followingRoute}/:userId',
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        // Provide FollowersBloc for FollowingPage
        child: BlocProvider<FollowersBloc>(
          create: (_) => di.sl<FollowersBloc>(),
          child: FollowingPage(userId: state.pathParameters['userId']!),
        ),
      ),
    ),

    // --- Main Stateful Shell Route for Tab Navigation ---
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        // Provide BLoCs needed by tabs that AREN'T GLOBAL
        return MultiBlocProvider(
          providers: [
            BlocProvider<FeedBloc>(create: (_) => di.sl<FeedBloc>()),
            BlocProvider<ReelsBloc>(create: (_) => di.sl<ReelsBloc>()),
            BlocProvider<UsersBloc>(create: (_) => di.sl<UsersBloc>()),
            BlocProvider<ProfileBloc>(create: (_) => di.sl<ProfileBloc>()),
            BlocProvider<UserPostsBloc>(create: (_) => di.sl<UserPostsBloc>()),
            BlocProvider<FollowersBloc>(create: (_) => di.sl<FollowersBloc>()),
            BlocProvider<NotificationsBloc>(
              create: (_) => di.sl<NotificationsBloc>(),
            ),
          ],
          child: MainPage(navigationShell: navigationShell),
        );
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
              routes: [
                // Nested Edit Profile Route
                GoRoute(
                  path: 'edit',
                  pageBuilder: (context, state) => SlideTransitionPage(
                    key: state.pageKey,
                    child: EditProfilePage(userId: 'me'),
                  ),
                ),
              ],
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
          child: MultiBlocProvider(
            providers: [
              // ONLY BLoCs required for profile data and posts
              BlocProvider<ProfileBloc>(
                create: (context) => di.sl<ProfileBloc>(),
              ),
              BlocProvider<UserPostsBloc>(
                create: (context) => di.sl<UserPostsBloc>(),
              ),
              BlocProvider<FollowersBloc>(
                create: (context) => di.sl<FollowersBloc>(),
              ),
            ],
            child: UserProfilePage(userId: userId),
          ),
        );
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Error: ${state.error?.message ?? "Page not found"}'),
    ),
  ),
  redirect: (context, state) async {
    final authState = context.read<AuthBloc>().state;
    final isLoggedIn = authState is AuthAuthenticated;
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
