import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/get_current_user_usecase.dart';
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
  final Set<int> _loadedTabs = {};

  @override
  void initState() {
    super.initState();
    AppLogger.info('Initializing MainPage');
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    AppLogger.info('Loading current user for MainPage');
    try {
      final result = await sl<GetCurrentUserUseCase>()(NoParams());
      result.fold(
        (failure) {
          if (failure is NetworkFailure) {
            AppLogger.warning(
              'Network error loading user, but will proceed with cached data: ${failure.message}',
            );
            FlutterNativeSplash.remove();
            final supabase = sl<SupabaseClient>();
            final sessionUserId = supabase.auth.currentUser?.id;
            if (sessionUserId != null && mounted) {
              setState(() => _userId = sessionUserId);
              _initializedPages = true;
              _syncSelectedIndexWithLocation();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _dispatchLoadForIndex(_selectedIndex);
                }
              });
            } else {
              if (context.mounted) context.go(Constants.loginRoute);
            }
          } else {
            AppLogger.error('Failed to load current user: ${failure.message}');
            FlutterNativeSplash.remove();
            if (context.mounted) context.go(Constants.loginRoute);
          }
        },
        (user) {
          AppLogger.info('Current user loaded: ${user.id}');
          if (mounted) {
            setState(() => _userId = user.id);
            FlutterNativeSplash.remove();
            _initializedPages = true;
            _syncSelectedIndexWithLocation();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _dispatchLoadForIndex(_selectedIndex);
              }
            });
          }
        },
      );
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
    if (location.startsWith(Constants.profileRoute)) return 3;
    if (location == Constants.usersRoute) return 2;
    if (location == Constants.reelsRoute) return 1;
    return 0;
  }

  void _syncSelectedIndexWithLocation() {
    final location = GoRouterState.of(context).uri.path;
    final idx = _calculateSelectedIndexFromLocation(location);
    if (mounted && idx != _selectedIndex) {
      setState(() => _selectedIndex = idx);
    }
  }

  void _dispatchLoadForIndex(int index) {
    if (_userId == null) return;
    if (_loadedTabs.contains(index)) return;
    _loadedTabs.add(index);

    AppLogger.info('Loading data for tab index: $index (user: $_userId)');
    switch (index) {
      case 0:
        context.read<PostsBloc>().add(GetFeedEvent(userId: _userId!));
        break;
      case 1:
        context.read<PostsBloc>().add(GetReelsEvent(userId: _userId!));
        break;
      case 2:
        context.read<UsersBloc>().add(GetAllUsersEvent(_userId!));
        break;
      case 3:
        context.read<ProfileBloc>().add(GetProfileDataEvent(_userId!));
        context.read<ProfileBloc>().add(StartProfileRealtimeEvent(_userId!));
        context.read<PostsBloc>().add(
          GetUserPostsEvent(profileUserId: _userId!, viewerUserId: _userId!),
        );
        break;
    }
  }

  void _onItemTapped(int index) {
    if (_userId == null) {
      AppLogger.warning('Cannot navigate, userId is null');
      return;
    }

    if (index != _selectedIndex && mounted) {
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
          route = '${Constants.profileRoute}/$_userId';
          break;
        default:
          route = Constants.feedRoute;
      }

      context.go(route);
      _dispatchLoadForIndex(index);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncSelectedIndexWithLocation();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null || !_initializedPages) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Build pages dynamically with visibility state
    final pages = [
      const FeedPage(key: PageStorageKey('feed_page')),
      ReelsPage(
        key: const PageStorageKey('reels_page'),
        isVisible: _selectedIndex == 1, //visibility state
      ),
      const UsersPage(key: PageStorageKey('users_page')),
      ProfilePage(key: const PageStorageKey('profile_page'), userId: _userId!),
    ];

    // Determine if the current page is Reels (index 1)
    final bool isReelsPage = _selectedIndex == 1;

    // Define colors based on the page state
    final Color barBackgroundColor = isReelsPage
        ? Colors
              .black // Forced dark background for Reels
        : Theme.of(context).scaffoldBackgroundColor; // Default theme background

    final Color unselectedColor = isReelsPage
        ? Colors.white.withOpacity(0.6) // Light unselected items for dark bar
        : Theme.of(
            context,
          ).colorScheme.onSurface.withOpacity(0.6); // Default theme color

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
        // Apply the conditional colors here
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
