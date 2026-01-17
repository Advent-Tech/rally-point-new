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
  final bool isOffline;

  const AuthAuthenticated({
    required this.user,
    this.isOffline = false,
  });

  @override
  List<Object?> get props => [user, isOffline];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}

/// State when user has registered but is pending verification
/// This is used for team leaders and workers who need admin/leader approval
class AuthPendingVerification extends AuthState {
  final String message;
  final String role; // team_leader or worker
  final String? email;

  const AuthPendingVerification({
    required this.message,
    required this.role,
    this.email,
  });

  @override
  List<Object?> get props => [message, role, email];
}

/// State when user needs to verify email before logging in
class AuthEmailVerificationRequired extends AuthState {
  final String message;
  final String email;

  const AuthEmailVerificationRequired({
    required this.message,
    required this.email,
  });

  @override
  List<Object?> get props => [message, email];
}

/// State when account has been rejected
class AuthAccountRejected extends AuthState {
  final String message;
  final String? reason;
  final String? email;

  const AuthAccountRejected({
    required this.message,
    this.reason,
    this.email,
  });

  @override
  List<Object?> get props => [message, reason, email];
}

/// State for forgot password flow
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

/// State when email verification is successful
class AuthEmailVerified extends AuthState {
  final String message;

  const AuthEmailVerified({required this.message});

  @override
  List<Object?> get props => [message];
}

/// State when password reset is successful
class AuthPasswordResetSuccess extends AuthState {
  final String message;

  const AuthPasswordResetSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

/// State for resend verification email success
class AuthResendVerificationSuccess extends AuthState {
  final String message;

  const AuthResendVerificationSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}
