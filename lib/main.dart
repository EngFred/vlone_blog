import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart' as di;
import 'package:vlone_blog_app/core/service/realtime_service.dart';
import 'package:vlone_blog_app/core/service/secure_storage.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:vlone_blog_app/features/settings/presentation/bloc/settings_bloc.dart';
import 'core/presentation/theme/app_theme.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:vlone_blog_app/features/comments/presentation/bloc/comments_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/post_actions/post_actions_bloc.dart';
import 'router.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  AppLogger.info('Initializing app dependencies');

  // Initializing Supabase first
  await Supabase.initialize(
    url: Constants.supabaseUrl,
    anonKey: Constants.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(localStorage: SecureStorage()),
  );

  di.initCoreServices();
  await di.initAuth(supabaseClient: Supabase.instance.client);
  await di.initRealtime();

  // Parallelizing other feature inits
  await Future.wait([
    di.initPosts(),
    di.initLikes(),
    di.initFavorites(),
    di.initComments(),
    di.initProfile(),
    di.initFollowers(),
    di.initUsers(),
    di.initNotifications(),
    di.initSettings(),
  ]);

  AppLogger.info('Starting app');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _didInitialAuthNavigate = false;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (_) => di.sl<AuthBloc>()..add(CheckAuthStatusEvent()),
      child: MultiBlocProvider(
        providers: [
          BlocProvider<CommentsBloc>(create: (_) => di.sl<CommentsBloc>()),
          BlocProvider<LikesBloc>(create: (_) => di.sl<LikesBloc>()),
          BlocProvider<FavoritesBloc>(create: (_) => di.sl<FavoritesBloc>()),
          BlocProvider<NotificationsBloc>(
            create: (_) => di.sl<NotificationsBloc>(),
          ),
          BlocProvider<PostActionsBloc>(
            create: (_) => di.sl<PostActionsBloc>(),
          ),
          BlocProvider<SettingsBloc>(create: (_) => di.sl<SettingsBloc>()),
        ],
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, state) {
            return MaterialApp.router(
              scaffoldMessengerKey: SnackbarUtils.scaffoldMessengerKey,
              title: Constants.appName,
              theme: AppTheme.lightTheme(),
              darkTheme: AppTheme.darkTheme(),
              themeMode: state.themeMode,
              routerConfig: appRouter,
              debugShowCheckedModeBanner: false,
              builder: (context, child) {
                return BlocListener<AuthBloc, AuthState>(
                  listener: (context, state) async {
                    if (state is AuthAuthenticated) {
                      AppLogger.info(
                        'AuthBloc: User authenticated, received AuthAuthenticated in MyApp listener',
                      );
                      FlutterNativeSplash.remove();

                      // navigate to feed only once on initial auth
                      if (!_didInitialAuthNavigate) {
                        _didInitialAuthNavigate = true;
                        appRouter.go(Constants.feedRoute);
                      } else {
                        AppLogger.info(
                          'Skipping navigation to feed because initial auth navigation already occurred.',
                        );
                      }

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
                      _didInitialAuthNavigate = false;
                      appRouter.go(Constants.loginRoute);

                      // Stopping realtime service when user logs out
                      try {
                        final realtime = di.sl<RealtimeService>();
                        if (realtime.isStarted) {
                          await realtime.stop();
                          AppLogger.info(
                            'RealtimeService stopped after logout',
                          );
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
            );
          },
        ),
      ),
    );
  }
}
