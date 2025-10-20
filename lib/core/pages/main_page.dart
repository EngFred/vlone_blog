import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:vlone_blog_app/features/posts/presentation/pages/feed_page.dart';
import 'package:vlone_blog_app/features/profile/presentation/pages/profile_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  String? _userId;
  int _selectedIndex = 0;
  late final List<Widget> _pages;
  bool _initializedPages = false;

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
          AppLogger.error('Failed to load current user: ${failure.message}');
          FlutterNativeSplash.remove();
          if (context.mounted) context.go(Constants.loginRoute);
        },
        (user) {
          AppLogger.info('Current user loaded: ${user.id}');
          if (mounted) {
            setState(() => _userId = user.id);
            FlutterNativeSplash.remove();
            _initPagesIfNeeded();
            _syncSelectedIndexWithLocation();
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

  void _initPagesIfNeeded() {
    if (_initializedPages || _userId == null) return;
    _pages = [
      const FeedPage(key: PageStorageKey('feed_page')),
      ProfilePage(key: const PageStorageKey('profile_page'), userId: _userId!),
      // Add more shell pages here if needed
    ];
    _initializedPages = true;
  }

  int _calculateSelectedIndexFromLocation(String location) {
    if (location.startsWith(Constants.profileRoute)) return 1;
    return 0;
  }

  void _syncSelectedIndexWithLocation() {
    final location = GoRouterState.of(context).uri.path;
    final idx = _calculateSelectedIndexFromLocation(location);
    if (mounted && idx != _selectedIndex) {
      setState(() => _selectedIndex = idx);
    }
  }

  void _onItemTapped(int index) {
    if (_userId == null) {
      AppLogger.warning('Cannot navigate, userId is null');
      return;
    }

    if (!_initializedPages) _initPagesIfNeeded();

    if (index == 0) {
      AppLogger.info('Navigating to Feed');
      context.go(Constants.feedRoute);
    } else if (index == 1) {
      AppLogger.info('Navigating to Profile for user: $_userId');
      context.go('${Constants.profileRoute}/$_userId');
    }

    if (mounted) setState(() => _selectedIndex = index);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Keep selected index in sync if user navigates with deep links / back button
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncSelectedIndexWithLocation();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null || !_initializedPages) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.feed), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Constants.primaryColor,
        unselectedItemColor: Theme.of(
          context,
        ).colorScheme.onSurface.withOpacity(0.6),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }
}
