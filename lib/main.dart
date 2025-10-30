import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart' as di;
import 'package:vlone_blog_app/core/service/realtime_service.dart';
import 'package:vlone_blog_app/core/theme/app_theme.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/comments/presentation/bloc/comments_bloc.dart';
import 'package:vlone_blog_app/features/followers/presentation/bloc/followers_bloc.dart';
import 'package:vlone_blog_app/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/feed/feed_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/post_actions/post_actions_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/reels/reels_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/user_posts/user_posts_bloc.dart';
import 'package:vlone_blog_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:vlone_blog_app/features/users/presentation/bloc/users_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'router.dart';

@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    AppLogger.info('Executing background task: $task');
    return Future.value(true);
  });
}

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  AppLogger.info('Initializing app dependencies');

  // Initialize Supabase first
  await Supabase.initialize(
    url: Constants.supabaseUrl,
    anonKey: Constants.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(localStorage: SecureStorage()),
  );

  // Call initAuth early, right after Supabase
  await di.initAuth(supabaseClient: Supabase.instance.client);

  await di.initRealtime();

  // Parallelize Workmanager and other feature inits
  await Future.wait([
    Workmanager().initialize(backgroundCallbackDispatcher),
    di.initPosts(),
    di.initLikes(),
    di.initFavorites(),
    di.initComments(),
    di.initProfile(),
    di.initFollowers(),
    di.initUsers(),
    di.initNotifications(),
  ]);

  AppLogger.info('Starting app');
  runApp(const MyApp());
}

class SecureStorage implements LocalStorage {
  final _storage = const FlutterSecureStorage();

  @override
  Future<void> initialize() async {
    AppLogger.info('Initializing secure storage for Supabase');
  }

  @override
  Future<bool> hasAccessToken() async {
    final token = await _storage.read(key: 'supabase_persisted_session');
    AppLogger.info('Checking access token in secure storage: ${token != null}');
    return token != null;
  }

  @override
  Future<String?> accessToken() async {
    final token = await _storage.read(key: 'supabase_persisted_session');
    AppLogger.info('Retrieved access token from secure storage');
    return token;
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    AppLogger.info('Persisting session to secure storage');
    await _storage.write(
      key: 'supabase_persisted_session',
      value: persistSessionString,
    );
  }

  @override
  Future<void> removePersistedSession() async {
    AppLogger.info('Removing persisted session from secure storage');
    await _storage.delete(key: 'supabase_persisted_session');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => di.sl<AuthBloc>()..add(CheckAuthStatusEvent()),
        ),
        BlocProvider<FeedBloc>(create: (_) => di.sl<FeedBloc>()),
        BlocProvider<ReelsBloc>(create: (_) => di.sl<ReelsBloc>()),
        // UserPostsBloc is often scoped, but keeping it global for now as it replaces part of old PostsBloc
        BlocProvider<UserPostsBloc>(create: (_) => di.sl<UserPostsBloc>()),
        BlocProvider<PostActionsBloc>(create: (_) => di.sl<PostActionsBloc>()),
        BlocProvider<ProfileBloc>(create: (_) => di.sl<ProfileBloc>()),
        BlocProvider<CommentsBloc>(create: (_) => di.sl<CommentsBloc>()),
        BlocProvider<FollowersBloc>(create: (_) => di.sl<FollowersBloc>()),
        BlocProvider<UsersBloc>(create: (_) => di.sl<UsersBloc>()),
        BlocProvider<LikesBloc>(create: (_) => di.sl<LikesBloc>()),
        BlocProvider<FavoritesBloc>(create: (_) => di.sl<FavoritesBloc>()),
        BlocProvider<NotificationsBloc>(
          create: (_) => di.sl<NotificationsBloc>(),
        ),
      ],
      child: MaterialApp.router(
        title: Constants.appName,
        theme: appTheme(),
        darkTheme: ThemeData.dark().copyWith(
          primaryColor: Constants.primaryColor,
          colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.blue,
            accentColor: Constants.accentColor,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: Colors.grey[900],
          textTheme: const TextTheme(
            headlineMedium: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: TextStyle(color: Colors.white70),
            bodyMedium: TextStyle(color: Colors.white60),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Constants.primaryColor, width: 2),
            ),
            fillColor: Colors.grey[800],
            filled: true,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: Colors.grey[900],
            selectedItemColor: Constants.primaryColor,
            unselectedItemColor: Colors.white60,
            showUnselectedLabels: true,
          ),
        ),
        themeMode: ThemeMode.system,
        routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return BlocListener<AuthBloc, AuthState>(
            listener: (context, state) async {
              try {
                ScaffoldMessenger.of(context).clearSnackBars();
              } catch (e) {
                AppLogger.warning(
                  'Failed to clear snackbars before auth navigation: $e',
                );
              }

              if (state is AuthAuthenticated) {
                AppLogger.info(
                  'AuthBloc: User authenticated, navigating to main page',
                );
                // Remove splash once we confirm auth and user is available
                FlutterNativeSplash.remove();
                appRouter.go(Constants.feedRoute);

                // START RealtimeService ONCE at app-level for the authenticated user.
                try {
                  final realtime = di.sl<RealtimeService>();
                  if (!realtime.isStarted) {
                    await realtime.start(state.user.id);
                    AppLogger.info(
                      'RealtimeService started from MyApp for user ${state.user.id}',
                    );
                  } else {
                    AppLogger.info('RealtimeService already started');
                  }
                } catch (e, st) {
                  AppLogger.error(
                    'Failed to start RealtimeService from MyApp: $e',
                    error: e,
                    stackTrace: st,
                  );
                }
              } else if (state is AuthUnauthenticated) {
                AppLogger.info(
                  'AuthBloc: User unauthenticated, navigating to login',
                );
                FlutterNativeSplash.remove();
                appRouter.go(Constants.loginRoute);

                // Stop realtime service when user logs out
                try {
                  final realtime = di.sl<RealtimeService>();
                  if (realtime.isStarted) {
                    await realtime.stop();
                    AppLogger.info('RealtimeService stopped after logout');
                  }
                } catch (e) {
                  AppLogger.warning(
                    'Failed to stop RealtimeService on logout: $e',
                  );
                }
              }
            },
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
