part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserModel user;

  const AuthAuthenticated({required this.user});

  @override
  List<Object?> get props => [user];

  bool get isSuperAdmin => user.isSuperAdmin;
  bool get isAdmin => user.isAdmin;
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}

/// State for forgot password flow success
class AuthForgotPasswordSuccess extends AuthState {
  final String message;
  final String email;

  const AuthForgotPasswordSuccess({
    required this.message,
    required this.email,
  });

  @override
  List<Object?> get props => [message, email];
}

/// State when password reset is successful
class AuthPasswordResetSuccess extends AuthState {
  final String message;

  const AuthPasswordResetSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}
