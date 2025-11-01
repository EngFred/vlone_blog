part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class SignupEvent extends AuthEvent {
  final String email;
  final String password;

  SignupEvent({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

class LoginEvent extends AuthEvent {
  final String email;
  final String password;

  LoginEvent({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

class LogoutEvent extends AuthEvent {}

class CheckAuthStatusEvent extends AuthEvent {}

class UpdateUserEvent extends AuthEvent {
  final UserEntity user;

  UpdateUserEvent(this.user);

  @override
  List<Object> get props => [user];
}
