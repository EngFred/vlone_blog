import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
import 'package:vlone_blog_app/core/utils/debouncer.dart';
import 'package:vlone_blog_app/core/utils/error_message_mapper.dart';
import 'package:vlone_blog_app/core/usecases/usecase.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
import 'package:vlone_blog_app/features/auth/domain/entities/user_entity.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:vlone_blog_app/features/auth/domain/usecases/signup_usecase.dart';
import 'package:vlone_blog_app/features/auth/domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SignupUseCase signupUseCase;
  final LoginUseCase loginUseCase;
  final LogoutUseCase logoutUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final AuthRepository authRepository;

  // Cache the authenticated user
  // This prevents redundant profile fetches throughout the app
  UserEntity? _cachedUser;

  AuthBloc({
    required this.signupUseCase,
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.getCurrentUserUseCase,
    required this.authRepository,
  }) : super(AuthInitial()) {
    on<SignupEvent>((event, emit) async {
      AppLogger.info('SignupEvent triggered for email: ${event.email}');
      emit(AuthLoading());
      final result = await signupUseCase(
        SignupParams(email: event.email, password: event.password),
      );
      result.fold(
        (failure) {
          final friendlyMessage = ErrorMessageMapper.getErrorMessage(failure);
          AppLogger.error('Signup failed: $friendlyMessage');
          emit(AuthError(friendlyMessage));
        },
        (user) {
          AppLogger.info('Signup successful for user: ${user.id}');
          _cachedUser = user; // ✅ Cache the user
          emit(AuthAuthenticated(user));
        },
      );
    });

    on<LoginEvent>((event, emit) async {
      AppLogger.info('LoginEvent triggered for email: ${event.email}');
      emit(AuthLoading());
      final result = await loginUseCase(
        LoginParams(email: event.email, password: event.password),
      );
      result.fold(
        (failure) {
          final friendlyMessage = ErrorMessageMapper.getErrorMessage(failure);
          AppLogger.error('Login failed: $friendlyMessage');
          emit(AuthError(friendlyMessage));
        },
        (user) {
          AppLogger.info('Login successful for user: ${user.id}');
          _cachedUser = user; // Cache the user
          emit(AuthAuthenticated(user));
        },
      );
    });

    on<LogoutEvent>((event, emit) async {
      AppLogger.info('LogoutEvent triggered');
      emit(AuthLoading());
      final result = await logoutUseCase(NoParams());
      result.fold(
        (failure) {
          final friendlyMessage = ErrorMessageMapper.getErrorMessage(failure);
          AppLogger.error('Logout failed: $friendlyMessage');
          emit(AuthError(friendlyMessage));
        },
        (_) async {
          AppLogger.info('Logout successful');

          // Cancel any pending debounced actions (important)
          // so no delayed follow/like/navigation happens after logout
          try {
            Debouncer.instance.cancelAll();
            AppLogger.info('Debouncer: canceled all pending actions on logout');
          } catch (e) {
            AppLogger.warning(
              'Failed to cancel debouncer actions on logout: $e',
            );
          }

          _cachedUser = null;
          emit(AuthUnauthenticated());
        },
      );
    });

    on<CheckAuthStatusEvent>((event, emit) async {
      AppLogger.info('CheckAuthStatusEvent triggered');

      // Check if session exists first using currentSession
      // This is a synchronous check that's much faster than restoreSession
      final sessionResult = await authRepository.restoreSession();

      await sessionResult.fold(
        (failure) async {
          AppLogger.info('Session restoration failed: ${failure.message}');
          _cachedUser = null;
          emit(AuthUnauthenticated());
        },
        (restored) async {
          if (restored) {
            AppLogger.info('Session restored, fetching current user');

            // ✅ PERFORMANCE: Emit loading state only if needed
            emit(AuthLoading());

            final userResult = await getCurrentUserUseCase(NoParams());
            userResult.fold(
              (failure) {
                final friendlyMessage = ErrorMessageMapper.getErrorMessage(
                  failure,
                );
                if (failure is NetworkFailure) {
                  AppLogger.warning(
                    'Network error but session exists: $friendlyMessage',
                  );
                  // If we have a cached user, use it for offline mode
                  if (_cachedUser != null) {
                    AppLogger.info('Using cached user for offline access');
                    emit(AuthAuthenticated(_cachedUser!));
                  } else {
                    emit(AuthUnauthenticated());
                  }
                } else {
                  AppLogger.info(
                    'Auth error, user unauthenticated: $friendlyMessage',
                  );
                  _cachedUser = null;
                  emit(AuthUnauthenticated());
                }
              },
              (user) {
                AppLogger.info('Current user found: ${user.id}');
                _cachedUser = user; // Cache the user
                emit(AuthAuthenticated(user));
              },
            );
          } else {
            AppLogger.info('No session to restore');
            _cachedUser = null;
            emit(AuthUnauthenticated());
          }
        },
      );
    });
  }

  // Provide access to cached user
  // Other parts of the app can use this instead of fetching again
  UserEntity? get cachedUser => _cachedUser;
}
