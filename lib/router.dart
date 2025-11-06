import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart' as di;
import 'package:vlone_blog_app/core/presentation/routes/slide_transition_page.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/auth/presentation/pages/login_page.dart';
import 'package:vlone_blog_app/features/auth/presentation/pages/signup_page.dart';
import 'package:vlone_blog_app/core/presentation/pages/main_page.dart';
import 'package:vlone_blog_app/features/posts/domain/entities/post_entity.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/feed/feed_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/reels/reels_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/user_posts/user_posts_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/create_post_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/feed_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/full_media_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/post_details_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/reels_page.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/edit_profile_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:vlone_blog_app/features/profile/presentation/pages/profile_page.dart';
import 'package:vlone_blog_app/features/profile/presentation/pages/user_profile_page.dart';
import 'package:vlone_blog_app/features/followers/presentation/bloc/followers_bloc.dart';
import 'package:vlone_blog_app/features/users/presentation/bloc/users_bloc.dart';
import 'package:vlone_blog_app/features/users/presentation/pages/user_list_page.dart';
import 'package:vlone_blog_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:vlone_blog_app/features/settings/presentation/pages/settings_page.dart';

/// The root navigator key used for top-level navigation, typically for
/// screens that overlay the entire application, like detail pages.
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Dedicated navigator keys for each branch of the main navigation shell.
final _shellNavigatorFeedKey = GlobalKey<NavigatorState>(debugLabel: 'feed');
final _shellNavigatorReelsKey = GlobalKey<NavigatorState>(debugLabel: 'reels');
final _shellNavigatorUsersKey = GlobalKey<NavigatorState>(debugLabel: 'users');
final _shellNavigatorProfileKey = GlobalKey<NavigatorState>(
  debugLabel: 'profile',
);

/// The application's main router configuration using GoRouter.
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

    // --- Secondary Detail Routes (Outside Main Navigation Shell) ---

    /// Notifications page, accessed from the main screen header.
    GoRoute(
      path: Constants.notificationsRoute,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const NotificationsPage(),
      ),
    ),

    /// Page for creating a new post.
    GoRoute(
      path: Constants.createPostRoute,
      pageBuilder: (context, state) => SlideTransitionPage(
        key: state.pageKey,
        child: const CreatePostPage(),
      ),
    ),

    /// Detail view for a single post, navigated using the post's ID.
    ///
    /// The route can optionally receive a cached [PostEntity] via `state.extra`
    /// to avoid refetching on navigation, and can accept comment IDs for deep linking.
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
          child: PostDetailsPage(
            postId: postId,
            post: extraPost,
            highlightCommentId: highlightCommentId,
            parentCommentId: parentCommentId,
          ),
        );
      },
    ),

    /// Full-screen media viewer for a post's image or video.
    ///
    /// Expects a [PostEntity] and an optional `heroTag` via `state.extra`.
    GoRoute(
      path: '/media',
      pageBuilder: (context, state) {
        PostEntity? post;
        String? heroTag;
        final extra = state.extra;
        if (extra is Map<String, dynamic>) {
          post = extra['post'] as PostEntity?;
          heroTag = extra['heroTag'] as String?;
        } else if (extra is PostEntity) {
          post = extra;
        }

        if (post == null) {
          return MaterialPage(
            key: state.pageKey,
            child: const Scaffold(
              body: Center(child: Text('Error: Media data not found.')),
            ),
          );
        }

        // Using MaterialPage here to allow Hero animations to work correctly
        // when transitioning from the previous route.
        return MaterialPage(
          key: state.pageKey,
          child: FullMediaPage(post: post, heroTag: heroTag),
        );
      },
    ),

    /// Page listing users who follow a given profile ID.
    ///
    /// Wraps the `UserListPage` in a `FollowersBloc` instance.
    GoRoute(
      path: '${Constants.followersRoute}/:userId',
      pageBuilder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return SlideTransitionPage(
          key: state.pageKey,
          child: BlocProvider<FollowersBloc>(
            create: (_) => di.sl<FollowersBloc>(),
            child: UserListPage(
              userId: userId,
              mode: UserListMode.followers,
              title: 'Followers',
            ),
          ),
        );
      },
    ),

    /// Page listing users a given profile ID is following.
    ///
    /// Wraps the `UserListPage` in a `FollowersBloc` instance.
    GoRoute(
      path: '${Constants.followingRoute}/:userId',
      pageBuilder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return SlideTransitionPage(
          key: state.pageKey,
          child: BlocProvider<FollowersBloc>(
            create: (_) => di.sl<FollowersBloc>(),
            child: UserListPage(
              userId: userId,
              mode: UserListMode.following,
              title: 'Following',
            ),
          ),
        );
      },
    ),

    // --- Main Stateful Shell Route for Tab Navigation ---

    /// Uses an indexed stack to preserve the state of navigators within each tab.
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        // Providing BLoCs here makes them available across all shell branches.
        return MultiBlocProvider(
          providers: [
            BlocProvider<FeedBloc>(create: (_) => di.sl<FeedBloc>()),
            BlocProvider<ReelsBloc>(create: (_) => di.sl<ReelsBloc>()),
            BlocProvider<UsersBloc>(create: (_) => di.sl<UsersBloc>()),
            BlocProvider<ProfileBloc>(create: (_) => di.sl<ProfileBloc>()),
            BlocProvider<UserPostsBloc>(create: (_) => di.sl<UserPostsBloc>()),
            BlocProvider<FollowersBloc>(create: (_) => di.sl<FollowersBloc>()),
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
              builder: (context, state) => const UserListPage(
                userId: null,
                mode: UserListMode.users,
                title: 'Discover People',
              ),
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
                /// Nested route for editing the current user's profile.
                GoRoute(
                  path: 'edit',
                  pageBuilder: (context, state) => SlideTransitionPage(
                    key: state.pageKey,
                    child: BlocProvider<EditProfileBloc>(
                      create: (_) => di.sl<EditProfileBloc>(),
                      child: EditProfilePage(userId: 'me'),
                    ),
                  ),
                ),

                /// Nested route for application settings.
                GoRoute(
                  path: 'settings',
                  pageBuilder: (context, state) => SlideTransitionPage(
                    key: state.pageKey,
                    child: const SettingsPage(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // --- Other User's Profile Page (outside shell) ---

    /// Route for viewing any user's profile based on their ID.
    GoRoute(
      path: '${Constants.profileRoute}/:userId',
      pageBuilder: (context, state) {
        final userId = state.pathParameters['userId']!;
        final authState = context.read<AuthBloc>().state;
        final currentUserId = authState is AuthAuthenticated
            ? authState.user.id
            : null;

        /// Redirecting to the 'me' tab if the user navigates to their own profile via ID.
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

        /// Providing necessary BLoCs scoped to this specific user's profile page.
        return SlideTransitionPage(
          key: state.pageKey,
          child: MultiBlocProvider(
            providers: [
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

  /// Global error handling for unhandled routes or navigation errors.
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Error: ${state.error?.message ?? "Page not found"}'),
    ),
  ),

  /// Global redirection logic for authentication enforcement.
  redirect: (context, state) async {
    final authState = context.read<AuthBloc>().state;
    final isLoggedIn = authState is AuthAuthenticated;
    final isAuthRoute =
        state.uri.path == Constants.loginRoute ||
        state.uri.path == Constants.signupRoute;

    /// User is not logged in and attempts to access a protected route.
    if (!isLoggedIn && !isAuthRoute) {
      return Constants.loginRoute;
    }

    /// User is logged in and attempts to access a login/signup route.
    if (isLoggedIn && isAuthRoute) {
      return Constants.feedRoute;
    }

    /// No redirection needed.
    return null;
  },
);
