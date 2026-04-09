part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckStatus extends AuthEvent {
  const AuthCheckStatus();
}

class AuthLogin extends AuthEvent {
  final String email;
  final String password;

  const AuthLogin({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class AuthLogout extends AuthEvent {
  const AuthLogout();
}

/// Event to request a forgot password email
class AuthForgotPassword extends AuthEvent {
  final String email;

  const AuthForgotPassword({required this.email});

  @override
  List<Object?> get props => [email];
}

/// Event to reset password with token
class AuthResetPassword extends AuthEvent {
  final String token;
  final String newPassword;

  const AuthResetPassword({
    required this.token,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [token, newPassword];
}

/// Event to clear error state
class AuthClearError extends AuthEvent {
  const AuthClearError();
}
