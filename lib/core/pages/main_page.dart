import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/get_current_user_usecase.dart';

class MainPage extends StatefulWidget {
  final Widget child;

  const MainPage({super.key, required this.child});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  String? _userId;

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

  int _calculateSelectedIndex() {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(Constants.profileRoute)) return 1;
    return 0; // default to feed
  }

  void _onItemTapped(int index) {
    if (_userId == null) {
      AppLogger.warning('Cannot navigate, userId is null');
      return;
    }

    if (index == 0) {
      AppLogger.info('Navigating to Feed');
      context.go(Constants.feedRoute);
    } else if (index == 1) {
      AppLogger.info('Navigating to Profile for user: $_userId');
      context.go('${Constants.profileRoute}/$_userId');
    }
  }

  @override
  Widget build(BuildContext context) {
    // The native splash screen will cover this widget, so the user
    // won't see this loading indicator on initial app start.
    if (_userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final selectedIndex = _calculateSelectedIndex();

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.feed), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: selectedIndex,
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
