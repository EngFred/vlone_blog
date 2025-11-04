import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/di/injection_container.dart' as di;
import 'package:vlone_blog_app/core/service/realtime_service.dart';
import 'package:vlone_blog_app/core/service/secure_storage.dart';
import 'package:vlone_blog_app/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:vlone_blog_app/features/settings/presentation/bloc/settings_bloc.dart';
import 'core/presentation/theme/app_theme.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:vlone_blog_app/features/comments/presentation/bloc/comments_bloc.dart';
import 'package:vlone_blog_app/features/likes/presentation/bloc/likes_bloc.dart';
import 'package:vlone_blog_app/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:vlone_blog_app/features/posts/presentation/bloc/post_actions/post_actions_bloc.dart';
import 'router.dart';

@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    AppLogger.info('Background task started: $task');

    // -----------------------------------------------------------------
    // 🌟 THIS IS THE LOGIC YOU NEED TO ADD 🌟
    // -----------------------------------------------------------------
    if (task == 'upload_post_media_task') {
      // 1. Initialize Supabase *in this background isolate*
      await Supabase.initialize(
        url: Constants.supabaseUrl,
        anonKey: Constants.supabaseAnonKey,
        authOptions: FlutterAuthClientOptions(localStorage: SecureStorage()),
      );
      final client = Supabase.instance.client;

      // 2. Get the data
      final input = inputData ?? {};
      final postId = input['postId'] as String?;
      final filePath = input['filePath'] as String?;
      final uploadPath = input['mediaUploadPath'] as String?;
      // Note: We don't need userId or mediaType for the re-upload

      if (postId == null || filePath == null || uploadPath == null) {
        AppLogger.error('Background task: Missing input data. Task failed.');
        return Future.value(false); // Task failed, will retry
      }

      // 3. Try to perform the upload
      try {
        final file = File(filePath);
        if (!await file.exists()) {
          AppLogger.error(
            'Background task: File $filePath does not exist. Task failed permanently.',
          );
          return Future.value(
            true,
          ); // Return true so it doesn't retry a impossible task
        }

        AppLogger.info('Background task: Uploading $filePath to $uploadPath');
        await client.storage.from('posts').upload(uploadPath, file);
        final mediaUrl = client.storage.from('posts').getPublicUrl(uploadPath);

        // 4. Update the post in the database
        await client
            .from('posts')
            .update({'media_url': mediaUrl, 'upload_status': 'completed'})
            .eq('id', postId);

        AppLogger.info('Background task: Upload for post $postId complete.');
        await file.delete(); // Clean up the temp file
        return Future.value(true); // Task succeeded
      } catch (e, st) {
        AppLogger.error(
          'Background task: Upload failed for post $postId: $e',
          error: e,
          stackTrace: st,
        );
        // On failure, update status to 'failed' so UI can show error
        try {
          await client
              .from('posts')
              .update({'upload_status': 'failed'})
              .eq('id', postId);
        } catch (_) {}

        return Future.value(false); // Task failed, Workmanager will retry
      }
    }
    // -----------------------------------------------------------------
    // 🌟 END OF NEW LOGIC 🌟
    // -----------------------------------------------------------------

    AppLogger.warning('Background task: No handler for task $task');
    return Future.value(true); // Acknowledge task was seen
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
  di.initCoreServices();
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
    // 1. AuthBloc remains at the root
    return BlocProvider<AuthBloc>(
      create: (_) => di.sl<AuthBloc>()..add(CheckAuthStatusEvent()),
      // 2. Wrap the entire app (MaterialApp.router) in MultiBlocProvider
      // for global access to interaction BLoCs.
      child: MultiBlocProvider(
        providers: [
          // ALL GLOBAL BLoCS
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
              title: Constants.appName,
              theme: AppTheme.lightTheme(),
              darkTheme: AppTheme.darkTheme(),
              themeMode: state.themeMode,
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
                        'AuthBloc: User authenticated, received AuthAuthenticated in MyApp listener',
                      );
                      FlutterNativeSplash.remove();
                      // ---- navigate to feed only once on initial auth ----
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
                      // Stop realtime service when user logs out
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
