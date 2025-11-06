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
  final List<String> _tabNames = const ['Feed', 'Reels', 'Users', 'Profile'];

  // Caching bloc references to avoid multiple context.read()
  FeedBloc? _feedBloc;
  ReelsBloc? _reelsBloc;
  ProfileBloc? _profileBloc;
  UserPostsBloc? _userPostsBloc;

  // Prevents multiple simultaneous operations
  Completer<void>? _currentOperation;

  @override
  void initState() {
    super.initState();
    AppLogger.info('Initializing MainPage (optimized)');
    WidgetsBinding.instance.addObserver(this);
    _cacheBlocs();
  }

  void _cacheBlocs() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _feedBloc = context.read<FeedBloc>();
      _reelsBloc = context.read<ReelsBloc>();
      _profileBloc = context.read<ProfileBloc>();
      _userPostsBloc = context.read<UserPostsBloc>();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_userId == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        AppLogger.info(
          'App resumed. Starting realtime for tab: ${_tabNames[_selectedIndex]}',
        );
        _startListenersForTab(_selectedIndex);
      case AppLifecycleState.paused:
        AppLogger.info(
          'App paused. Stopping realtime for tab: ${_tabNames[_selectedIndex]}',
        );
        _stopListenersForTab(_selectedIndex);
      default:
        break;
    }
  }

  void _startListenersForTab(int index) {
    if (_userId == null) return;

    switch (index) {
      case 0: // Feed
        _feedBloc?.add(const StartFeedRealtime());
        break;
      case 1: // Reels
        _reelsBloc?.add(const StartReelsRealtime());
        break;
      case 3: // Profile
        _profileBloc?.add(StartProfileRealtimeEvent(_userId!));
        _userPostsBloc?.add(StartUserPostsRealtime(profileUserId: _userId!));
        break;
      default:
        break;
    }
  }

  void _stopListenersForTab(int index) {
    switch (index) {
      case 0: // Feed
        _feedBloc?.add(const StopFeedRealtime());
        break;
      case 1: // Reels
        _reelsBloc?.add(const StopReelsRealtime());
        break;
      case 3: // Profile
        _profileBloc?.add(StopProfileRealtimeEvent());
        _userPostsBloc?.add(const StopUserPostsRealtime());
        break;
      default:
        break;
    }
  }

  void _onAuthUpdated(String? userId) {
    if (userId == null || (!mounted)) return;
    if (_userId == userId && _initializedPages) return;

    final bool userIdChanged = _userId != userId;

    setState(() {
      _userId = userId;
      _initializedPages = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (userIdChanged) {
        _loadedTabs.clear();
        _stopListenersForTab(_selectedIndex);
      }

      _selectedIndex = widget.navigationShell.currentIndex;

      AppLogger.info(
        'MainPage: Auth updated. Loading tab: ${_tabNames[_selectedIndex]}',
      );

      // Single operation sequencing
      _switchToTab(_selectedIndex).then((_) {
        FlutterNativeSplash.remove();
      });
    });
  }

  Future<void> _switchToTab(int newIndex) async {
    if (_currentOperation != null) {
      await _currentOperation!.future;
    }

    final completer = Completer<void>();
    _currentOperation = completer;

    try {
      if (newIndex != _selectedIndex) {
        _stopListenersForTab(_selectedIndex);
      }

      if (!_loadedTabs.contains(newIndex)) {
        _dispatchLoadForIndex(newIndex);
        await Future.delayed(const Duration(milliseconds: 50));
      }

      _startListenersForTab(newIndex);

      if (mounted && newIndex != _selectedIndex) {
        setState(() => _selectedIndex = newIndex);
      }

      completer.complete();
    } catch (e) {
      completer.completeError(e);
    } finally {
      if (_currentOperation == completer) {
        _currentOperation = null;
      }
    }
  }

  void _dispatchLoadForIndex(int index) {
    if (_userId == null || _loadedTabs.contains(index)) return;

    _loadedTabs.add(index);
    AppLogger.info('Loading tab: ${_tabNames[index]}');

    switch (index) {
      case 0:
        _feedBloc?.add(GetFeedEvent(_userId!));
        break;
      case 1:
        _reelsBloc?.add(GetReelsEvent(_userId!));
        break;
      case 2:
        context.read<UsersBloc>().add(GetPaginatedUsersEvent(_userId!));
        break;
      case 3:
        _profileBloc?.add(GetProfileDataEvent(_userId!));
        _userPostsBloc?.add(
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

    HapticFeedback.lightImpact();
    AppLogger.info('Bottom nav tapped: ${_tabNames[index]}');

    if (!mounted) return;

    if (index != _selectedIndex) {
      Navigator.of(context).popUntil((route) => route.isFirst);

      _switchToTab(index).then((_) {
        widget.navigationShell.goBranch(
          index,
          initialLocation: index == widget.navigationShell.currentIndex,
        );
      });
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
    if (_userId != null) {
      _stopListenersForTab(_selectedIndex);
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

    // Handle external navigation
    if (_selectedIndex != widget.navigationShell.currentIndex) {
      final newIndex = widget.navigationShell.currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _switchToTab(newIndex);
      });
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
        currentIndex: _selectedIndex,
        selectedItemColor: Constants.primaryColor,
        unselectedItemColor: unselectedColor,
        backgroundColor: barBackgroundColor,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
    );
  }
}
