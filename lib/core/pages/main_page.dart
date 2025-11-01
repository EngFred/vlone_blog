import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/feed/feed_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/reels/reels_bloc.dart';
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

  // Handle app lifecycle events for Realtime
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_userId == null) return;
    if (state == AppLifecycleState.resumed) {
      AppLogger.info('App resumed. Starting Feed/Reels realtime listeners.');
      // Restart realtime subscriptions when app resumes
      context.read<FeedBloc>().add(const StartFeedRealtime());
      context.read<ReelsBloc>().add(const StartReelsRealtime());
      context.read<ProfileBloc>().add(StartProfileRealtimeEvent(_userId!));
    } else if (state == AppLifecycleState.paused) {
      AppLogger.info('App paused. Stopping Feed/Reels realtime listeners.');
      // Stop realtime subscriptions when app pauses
      context.read<FeedBloc>().add(const StopFeedRealtime());
      context.read<ReelsBloc>().add(const StopReelsRealtime());
      context.read<ProfileBloc>().add(StopProfileRealtimeEvent());
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
      }

      // Sync the selected index with the shell
      _selectedIndex = widget.navigationShell.currentIndex;

      AppLogger.info(
        'MainPage: Auth updated. Loading initial tab: ${_tabNames[_selectedIndex]}',
      );

      // START Realtime Listeners (moved from MyApp to here, specific to BLoCs)
      context.read<FeedBloc>().add(const StartFeedRealtime());
      context.read<ReelsBloc>().add(const StartReelsRealtime());
      context.read<ProfileBloc>().add(StartProfileRealtimeEvent(_userId!));

      _dispatchLoadForIndex(_selectedIndex);
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
    }

    // Use shell to navigate to the branch
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );

    // Update the selected index and dispatch load event if needed
    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
      _dispatchLoadForIndex(index);
    } else {
      AppLogger.info('Re-tap on current tab: ${_tabNames[index]}');
      // Optional: Add refresh logic for re-taps here if desired
    }
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
    // Stop Realtime when the MainPage is disposed (e.g., user logs out)
    if (_userId != null) {
      context.read<FeedBloc>().add(const StopFeedRealtime());
      context.read<ReelsBloc>().add(const StopReelsRealtime());
      context.read<ProfileBloc>().add(StopProfileRealtimeEvent());
      AppLogger.info('MainPage disposed. Realtime listeners stopped.');
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
      setState(() => _selectedIndex = widget.navigationShell.currentIndex);
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
