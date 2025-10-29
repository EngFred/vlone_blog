import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/feed_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/reels_page.dart';
import 'package:vlone_blog_app/features/profile/presentation/pages/profile_page.dart';
import 'package:vlone_blog_app/features/users/presentation/pages/users_page.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/posts_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:vlone_blog_app/features/users/presentation/bloc/users_bloc.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/notifications/presentation/bloc/notifications_bloc.dart'; // Added for notifications

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  String? _userId;
  int _selectedIndex = 0;
  bool _initializedPages = false;
  final Set<int> _loadedTabs = {};
  //Helper list for readable log messages
  final List<String> _tabNames = const ['Feed', 'Reels', 'Users', 'Profile'];

  @override
  void initState() {
    super.initState();
    AppLogger.info('Initializing MainPage (now auth-driven)');
    // no direct supabase call here. We can wait for AuthBloc to provide the user.
  }

  void _onAuthUpdated(String? userId) {
    if (userId == null) return;
    if (_userId == userId && _initializedPages) return;
    setState(() {
      _userId = userId;
      _initializedPages = true;
    });
    // sync location and load the default tab once the first frame is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncSelectedIndexWithLocation();
      // Pass tab name to the log
      AppLogger.info(
        'MainPage: Auth updated. Loading initial tab: ${_tabNames[_selectedIndex]}',
      );
      // Added: Global setups - start realtime listeners and notifications once here
      context.read<PostsBloc>().add(StartRealtimeListenersEvent(_userId!));
      context.read<NotificationsBloc>().add(
        NotificationsSubscribeUnreadCountStream(),
      );
      AppLogger.info('Subscribed to notifications and realtime from MainPage');
      _dispatchLoadForIndex(_selectedIndex);
      FlutterNativeSplash.remove(); // in case it wasn't removed yet
    });
  }

  int _calculateSelectedIndexFromLocation(String location) {
    if (location == '${Constants.profileRoute}/me') return 3;
    if (location == Constants.usersRoute) return 2;
    if (location == Constants.reelsRoute) return 1;
    return 0;
  }

  void _syncSelectedIndexWithLocation() {
    try {
      final location = GoRouterState.of(context).uri.path;
      final idx = _calculateSelectedIndexFromLocation(location);
      // ✅ ADDED: Log for initial sync
      AppLogger.info(
        'Syncing location: $location resolved to tab ${_tabNames[idx]} (index $idx)',
      );
      if (mounted && idx != _selectedIndex) {
        setState(() => _selectedIndex = idx);
      }
    } catch (e) {
      AppLogger.warning('Failed to sync location: $e');
    }
  }

  void _dispatchLoadForIndex(int index) {
    if (_userId == null) return;
    //Made log message more readable
    AppLogger.info(
      'Dispatching load for tab: ${_tabNames[index]} (index $index, user: $_userId)',
    );
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
        context.read<UsersBloc>().add(GetPaginatedUsersEvent(_userId!));
        break;
      case 3:
        if (_loadedTabs.contains(3)) return;
        _loadedTabs.add(3);
        context.read<ProfileBloc>().add(GetProfileDataEvent(_userId!));
        context.read<ProfileBloc>().add(StartProfileRealtimeEvent(_userId!));
        context.read<PostsBloc>().add(
          GetUserPostsEvent(profileUserId: _userId!, currentUserId: _userId!),
        );
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
    //Log for every tap event
    AppLogger.info('Bottom nav tapped: ${_tabNames[index]} (index $index)');
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
        route = '${Constants.profileRoute}/me';
        break;
      default:
        route = Constants.feedRoute;
    }
    if (!mounted) return;
    if (index != _selectedIndex) {
      // ✅ ADDED: Log for when the tab *changes*
      AppLogger.info('Navigating to tab: ${_tabNames[index]}');
      setState(() => _selectedIndex = index);
      context.go(route);
      _dispatchLoadForIndex(index);
    } else {
      // ✅ ADDED: Log for when the *same tab* is re-tapped
      AppLogger.info('Re-tap on current tab: ${_tabNames[index]}');
      if (index == 3) {
        AppLogger.info('Re-tap on Profile tab detected - full profile refresh');
        _dispatchLoadForIndex(3);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Try to read cached user right away from AuthBloc
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _onAuthUpdated(authState.user.id);
    }
    // If the auth state changes later, the BlocListener in build will pick it up.
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          _onAuthUpdated(state.user.id);
        } else if (state is AuthUnauthenticated) {
          // router's redirect usually handles actual navigation; keep UI reactiveness
          AppLogger.info('Auth state became unauthenticated on MainPage');
        }
      },
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    if (_userId == null || !_initializedPages) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pages = [
      FeedPage(key: const PageStorageKey('feed_page')),
      ReelsPage(
        key: const PageStorageKey('reels_page'),
        isVisible: _selectedIndex == 1,
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
}
