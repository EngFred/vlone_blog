import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vlone_blog_app/core/error/failures.dart';
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
        SignupParams(
          email: event.email,
          password: event.password,
          username: event.username,
        ),
      );
      result.fold(
        (failure) {
          AppLogger.error('Signup failed: ${failure.message}');
          emit(AuthError(failure.message));
        },
        (user) {
          AppLogger.info('Signup successful for user: ${user.id}');
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
          AppLogger.error('Login failed: ${failure.message}');
          emit(AuthError(failure.message));
        },
        (user) {
          AppLogger.info('Login successful for user: ${user.id}');
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
          AppLogger.error('Logout failed: ${failure.message}');
          emit(AuthError(failure.message));
        },
        (_) {
          AppLogger.info('Logout successful');
          emit(AuthUnauthenticated());
        },
      );
    });

    on<CheckAuthStatusEvent>((event, emit) async {
      AppLogger.info('CheckAuthStatusEvent triggered');
      emit(AuthLoading());

      final sessionResult = await authRepository.restoreSession();
      await sessionResult.fold(
        (failure) async {
          AppLogger.info('Session restoration failed: ${failure.message}');
          emit(AuthUnauthenticated());
        },
        (restored) async {
          if (restored) {
            AppLogger.info('Session restored, checking current user');
            final userResult = await getCurrentUserUseCase(NoParams());
            userResult.fold(
              (failure) {
                // CRITICAL: Handle network failures differently
                if (failure is NetworkFailure) {
                  AppLogger.warning(
                    'Network error but session exists, treating as authenticated: ${failure.message}',
                  );
                  // Create a minimal user entity from session
                  // This allows offline access
                  emit(
                    AuthUnauthenticated(),
                  ); // Will be handled by router redirect
                } else {
                  AppLogger.info(
                    'Auth error, user unauthenticated: ${failure.message}',
                  );
                  emit(AuthUnauthenticated());
                }
              },
              (user) {
                AppLogger.info('Current user found: ${user.id}');
                emit(AuthAuthenticated(user));
              },
            );
          } else {
            AppLogger.info('No session to restore');
            emit(AuthUnauthenticated());
          }
        },
      );
    });
  }
}
