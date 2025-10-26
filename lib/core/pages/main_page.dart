import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/feed_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/reels_page.dart';
import 'package:vlone_blog_app/features/profile/presentation/pages/profile_page.dart';
import 'package:vlone_blog_app/features/users/presentation/pages/users_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:vlone_blog_app/features/users/presentation/bloc/users_bloc.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  String? _userId;
  int _selectedIndex = 0;
  bool _initializedPages = false;
  bool _locationSynced = false;
  final Set<int> _loadedTabs = {};

  @override
  void initState() {
    super.initState();
    AppLogger.info('Initializing MainPage');
    _loadCurrentUser();
  }

  /// ✅ OPTIMIZED: Get userId directly from Supabase session
  /// No need to fetch profile again - AuthBloc already did that
  Future<void> _loadCurrentUser() async {
    AppLogger.info('Loading current user for MainPage');
    try {
      final supabase = sl<SupabaseClient>();
      final sessionUserId = supabase.auth.currentUser?.id;
      if (sessionUserId == null) {
        AppLogger.error('No user session found in MainPage');
        FlutterNativeSplash.remove();
        if (context.mounted) context.go(Constants.loginRoute);
        return;
      }
      AppLogger.info('Current user loaded from session: $sessionUserId');
      if (mounted) {
        setState(() => _userId = sessionUserId);
        _initializedPages = true;

        // Wait for first frame, then sync location
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _syncSelectedIndexWithLocation();
            // Load default tab (feed) immediately
            _dispatchLoadForIndex(_selectedIndex);
          }
        });
        FlutterNativeSplash.remove();
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Unexpected error loading user: $e',
        error: e,
        stackTrace: stackTrace,
      );
      FlutterNativeSplash.remove();
      if (context.mounted) context.go(Constants.loginRoute);
    }
  }

  int _calculateSelectedIndexFromLocation(String location) {
    // Check for /profile/me route (bottom nav profile)
    if (location == '${Constants.profileRoute}/me') return 3;
    if (location == Constants.usersRoute) return 2;
    if (location == Constants.reelsRoute) return 1;
    return 0;
  }

  /// Sync selected index with current router location
  void _syncSelectedIndexWithLocation() {
    try {
      final location = GoRouterState.of(context).uri.path;
      final idx = _calculateSelectedIndexFromLocation(location);
      if (mounted && idx != _selectedIndex) {
        setState(() => _selectedIndex = idx);
        _locationSynced = true;
      }
    } catch (e) {
      AppLogger.warning('Failed to sync location: $e');
      _locationSynced = true;
    }
  }

  /// Load data for the provided tab index.
  /// IMPORTANT: For profile (index 3) we ALWAYS refresh header, realtime, and posts.
  void _dispatchLoadForIndex(int index) {
    if (_userId == null) return;

    AppLogger.info('Loading data for tab index: $index (user: $_userId)');

    switch (index) {
      case 0:
        if (_loadedTabs.contains(0)) return;
        _loadedTabs.add(0);
        context.read<PostsBloc>().add(GetFeedEvent(_userId!));
        break;
      case 1:
        if (_loadedTabs.contains(1)) return;
        _loadedTabs.add(1);
        context.read<PostsBloc>().add(GetReelsEvent(_userId!));
        break;
      case 2:
        if (_loadedTabs.contains(2)) return;
        _loadedTabs.add(2);
        context.read<UsersBloc>().add(GetAllUsersEvent(_userId!));
        break;
      case 3:
        // ALWAYS refresh profile header & realtime
        context.read<ProfileBloc>().add(GetProfileDataEvent(_userId!));
        context.read<ProfileBloc>().add(StartProfileRealtimeEvent(_userId!));

        // ALWAYS refresh profile posts as well (user requested full profile refresh)
        context.read<PostsBloc>().add(
          GetUserPostsEvent(profileUserId: _userId!, currentUserId: _userId!),
        );

        // Note: we intentionally do NOT gate posts by _loadedTabs here because
        // user requested that the entire profile (including posts) refresh on tap.
        break;
      default:
        break;
    }
  }

  void _onItemTapped(int index) {
    if (_userId == null) {
      AppLogger.warning('Cannot navigate, userId is null');
      return;
    }

    // Determine route for the requested index
    String route;
    switch (index) {
      case 0:
        route = Constants.feedRoute;
        break;
      case 1:
        route = Constants.reelsRoute;
        break;
      case 2:
        route = Constants.usersRoute;
        break;
      case 3:
        // Navigate to /profile/me for bottom nav profile
        route = '${Constants.profileRoute}/me';
        break;
      default:
        route = Constants.feedRoute;
    }

    if (!mounted) return;

    if (index != _selectedIndex) {
      // Normal tab switch
      setState(() => _selectedIndex = index);
      context.go(route);
      _dispatchLoadForIndex(index); // Lazy load on tap (profile included)
    } else {
      // User tapped the currently selected tab.
      // If it's the Profile tab, refresh the entire profile page including posts.
      if (index == 3) {
        AppLogger.info('Re-tap on Profile tab detected - full profile refresh');
        _dispatchLoadForIndex(3);
        // Optionally: scroll-to-top or other UI refresh actions can be triggered here.
      } else {
        // For other tabs you might implement "scroll to top" behavior if desired.
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync location changes when route updates
    if (_initializedPages && _locationSynced) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            final location = GoRouterState.of(context).uri.path;
            final idx = _calculateSelectedIndexFromLocation(location);
            if (idx != _selectedIndex) {
              setState(() => _selectedIndex = idx);
              _dispatchLoadForIndex(idx); // Lazy load if location changes
            }
          } catch (e) {
            AppLogger.warning(
              'Failed to sync location in didChangeDependencies: $e',
            );
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null || !_initializedPages) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Pages built with PageStorageKey for state preservation
    final pages = [
      FeedPage(key: const PageStorageKey('feed_page'), userId: _userId!),
      ReelsPage(
        key: const PageStorageKey('reels_page'),
        isVisible: _selectedIndex == 1,
        userId: _userId!,
      ),
      const UsersPage(key: PageStorageKey('users_page')),
      ProfilePage(key: const PageStorageKey('profile_page'), userId: _userId!),
    ];

    final bool isReelsPage = _selectedIndex == 1;
    final Color barBackgroundColor = isReelsPage
        ? Colors.black
        : Theme.of(context).scaffoldBackgroundColor;
    final Color unselectedColor = isReelsPage
        ? Colors.white.withOpacity(0.6)
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6);

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.feed), label: 'Feed'),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library),
            label: 'Reels',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Constants.primaryColor,
        unselectedItemColor: unselectedColor,
        backgroundColor: barBackgroundColor,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
