import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/feed/feed_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/reels/reels_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/user_posts/user_posts_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:vlone_blog_app/features/users/presentation/bloc/users_bloc.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';

class MainPage extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const MainPage({super.key, required this.navigationShell});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  String? _userId;
  int _selectedIndex = 0;
  bool _initializedPages = false;
  final Set<int> _loadedTabs = {};
  // Helper list for readable log messages
  final List<String> _tabNames = const ['Feed', 'Reels', 'Users', 'Profile'];

  @override
  void initState() {
    super.initState();
    AppLogger.info('Initializing MainPage (now auth-driven)');
    WidgetsBinding.instance.addObserver(this);
  }

  // Handle app lifecycle events for Realtime (now tab-specific)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_userId == null) return;
    if (state == AppLifecycleState.resumed) {
      AppLogger.info(
        'App resumed. Starting realtime for current tab: ${_tabNames[_selectedIndex]}.',
      );
      _startListenersForTab(_selectedIndex);
    } else if (state == AppLifecycleState.paused) {
      AppLogger.info(
        'App paused. Stopping realtime for current tab: ${_tabNames[_selectedIndex]}.',
      );
      _stopListenersForTab(_selectedIndex);
    }
  }

  void _startListenersForTab(int index) {
    if (_userId == null) return;
    switch (index) {
      case 0: // Feed
        context.read<FeedBloc>().add(const StartFeedRealtime());
        AppLogger.info('Started Feed realtime');
        break;
      case 1: // Reels
        context.read<ReelsBloc>().add(const StartReelsRealtime());
        AppLogger.info('Started Reels realtime');
        break;
      case 3: // Profile (own profile)
        context.read<ProfileBloc>().add(StartProfileRealtimeEvent(_userId!));
        context.read<UserPostsBloc>().add(
          StartUserPostsRealtime(profileUserId: _userId!),
        );
        AppLogger.info('Started Profile/UserPosts realtime for $_userId');
        break;
      default:
        break; // Users tab: no realtime
    }
  }

  void _stopListenersForTab(int index) {
    switch (index) {
      case 0: // Feed
        context.read<FeedBloc>().add(const StopFeedRealtime());
        AppLogger.info('Stopped Feed realtime');
        break;
      case 1: // Reels
        context.read<ReelsBloc>().add(const StopReelsRealtime());
        AppLogger.info('Stopped Reels realtime');
        break;
      case 3: // Profile
        context.read<ProfileBloc>().add(StopProfileRealtimeEvent());
        context.read<UserPostsBloc>().add(const StopUserPostsRealtime());
        AppLogger.info('Stopped Profile/UserPosts realtime');
        break;
      default:
        break;
    }
  }

  void _onAuthUpdated(String? userId) {
    if (userId == null) return;
    if (_userId == userId && _initializedPages) return;
    if (!mounted) return; // Safety check for production robustness

    // If user changed or not initialized, update state
    final bool userIdChanged = _userId != userId;
    setState(() {
      _userId = userId;
      _initializedPages = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (userIdChanged) {
        // If the user ID changes (e.g., re-login), clear loaded tabs
        _loadedTabs.clear();
        // Stop any lingering listeners from previous user
        _stopListenersForTab(_selectedIndex);
      }

      // Sync the selected index with the shell
      _selectedIndex = widget.navigationShell.currentIndex;

      AppLogger.info(
        'MainPage: Auth updated. Loading initial tab: ${_tabNames[_selectedIndex]}',
      );

      // FIX #2: Dispatch load FIRST, then start realtime (order matters for async safety)
      _dispatchLoadForIndex(_selectedIndex);
      // Use microtask to sequence: Ensures load event is queued before realtime
      // (Blocs will guard realtime start until loaded—see notes below)
      scheduleMicrotask(() => _startListenersForTab(_selectedIndex));

      FlutterNativeSplash.remove(); // in case it wasn't removed yet
    });
  }

  void _dispatchLoadForIndex(int index) {
    if (_userId == null) return;
    if (_loadedTabs.contains(index)) return; // Don't reload

    _loadedTabs.add(index);
    AppLogger.info(
      'Dispatching load for tab: ${_tabNames[index]} (index $index, user: $_userId)',
    );

    switch (index) {
      case 0:
        context.read<FeedBloc>().add(GetFeedEvent(_userId!));
        break;
      case 1:
        context.read<ReelsBloc>().add(GetReelsEvent(_userId!));
        break;
      case 2:
        context.read<UsersBloc>().add(GetPaginatedUsersEvent(_userId!));
        break;
      case 3:
        context.read<ProfileBloc>().add(GetProfileDataEvent(_userId!));
        // Also load the signed-in user's posts for the Profile tab
        context.read<UserPostsBloc>().add(
          GetUserPostsEvent(profileUserId: _userId!, currentUserId: _userId!),
        );
        break;
      default:
        break;
    }
  }

  // FIX #1: Async-ify for race safety—await stop completion via microtasks
  Future<void> _swapListenersAndLoad(int newIndex) async {
    if (newIndex == _selectedIndex) return;

    // Sequence: Stop old (sync queue), then load new, then start new
    // Microtasks ensure event order without blocking UI thread
    _stopListenersForTab(_selectedIndex);
    await Future.microtask(
      () {},
    ); // Yield to let stop process (negligible delay)

    // Load first (FIX #2)
    _dispatchLoadForIndex(newIndex);
    await Future.microtask(() {}); // Yield for load to queue

    // Then start
    _startListenersForTab(newIndex);
  }

  void _onItemTapped(int index) {
    if (_userId == null) {
      AppLogger.warning('Cannot navigate, userId is null');
      return;
    }

    // --- UX Touch ---
    // Add haptic feedback for a more tactile feel
    HapticFeedback.lightImpact();
    // --- End UX Touch ---

    AppLogger.info('Bottom nav tapped: ${_tabNames[index]} (index $index)');

    if (!mounted) return;

    if (index != _selectedIndex) {
      // Close any open modals (e.g., comment overlays) when switching tabs
      while (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // FIX #1 & #2: Use sequenced swap (async, but non-blocking)
      _swapListenersAndLoad(index).then((_) {
        if (mounted) {
          setState(() => _selectedIndex = index);
        }
      });

      // Note: goBranch is sync and fast—doesn't block the async swap
    } else {
      AppLogger.info('Re-tap on current tab: ${_tabNames[index]}');
      // Optional: Add refresh logic for re-taps here if desired
    }

    // Use shell to navigate to the branch
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _onAuthUpdated(authState.user.id);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop realtime for the current tab on dispose
    if (_userId != null) {
      _stopListenersForTab(_selectedIndex);
      AppLogger.info(
        'MainPage disposed. Realtime listeners for current tab stopped.',
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          _onAuthUpdated(state.user.id);
        } else if (state is AuthUnauthenticated) {
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

    // Sync selected index with shell (in case of external navigation)
    if (_selectedIndex != widget.navigationShell.currentIndex) {
      // FIX #1: Sequence the swap here too (for desync edges)
      final oldIndex = _selectedIndex;
      final newIndex = widget.navigationShell.currentIndex;
      setState(() => _selectedIndex = newIndex);
      if (oldIndex != newIndex) {
        _swapListenersAndLoad(newIndex); // Reuse the sequenced method
      }
    }

    final bool isReelsPage = _selectedIndex == 1;
    final Color barBackgroundColor = isReelsPage
        ? Colors.black
        : Theme.of(context).scaffoldBackgroundColor;
    final Color unselectedColor = isReelsPage
        ? Colors.white.withOpacity(0.6)
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6);

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        // --- UX Touch: Use activeIcon for filled/outline state ---
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_filled),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library_outlined),
            activeIcon: Icon(Icons.video_library),
            label: 'Reels',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        // --- End UX Touch ---
        currentIndex: _selectedIndex,
        selectedItemColor: Constants.primaryColor,
        unselectedItemColor: unselectedColor,
        backgroundColor: barBackgroundColor,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        // --- UX Touch: Explicitly show labels ---
        showSelectedLabels: true,
        showUnselectedLabels: true,
        // --- End UX Touch ---
      ),
    );
  }
}
