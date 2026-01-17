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

class AuthRegister extends AuthEvent {
  final String email;
  final String password;
  final String displayName;
  final String? firstName;
  final String? lastName;
  final String? teamId;
  final String? teamName; // For team leaders creating a new team
  final String role; // worker, team_leader, admin

  const AuthRegister({
    required this.email,
    required this.password,
    required this.displayName,
    this.firstName,
    this.lastName,
    this.teamId,
    this.teamName,
    this.role = 'worker',
  });

  @override
  List<Object?> get props => [email, password, displayName, firstName, lastName, teamId, teamName, role];
}

class AuthLogout extends AuthEvent {
  const AuthLogout();
}

class AuthUpdateUser extends AuthEvent {
  final UserModel user;

  const AuthUpdateUser({required this.user});

  @override
  List<Object?> get props => [user];
}

class AuthRefreshToken extends AuthEvent {
  const AuthRefreshToken();
}

class AuthTokenExpired extends AuthEvent {
  const AuthTokenExpired();
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

/// Event to verify email with token
class AuthVerifyEmail extends AuthEvent {
  final String token;

  const AuthVerifyEmail({required this.token});

  @override
  List<Object?> get props => [token];
}

/// Event to resend verification email
class AuthResendVerification extends AuthEvent {
  final String email;

  const AuthResendVerification({required this.email});

  @override
  List<Object?> get props => [email];
}

/// Event to clear any error state and return to unauthenticated
class AuthClearError extends AuthEvent {
  const AuthClearError();
}
