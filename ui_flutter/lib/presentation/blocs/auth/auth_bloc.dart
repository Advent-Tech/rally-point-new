import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/user_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/constants/api_constants.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Helper function to extract user-friendly error message from exceptions
String _extractErrorMessage(dynamic error) {
  if (error is DioException) {
    // Try to get error message from response data
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      // Backend returns {"error": "message"}
      final errorMsg = responseData['error'] ?? responseData['message'];
      if (errorMsg != null) {
        return errorMsg.toString();
      }
    }
    // Fallback to status message or generic message
    if (error.response?.statusMessage != null) {
      return error.response!.statusMessage!;
    }
    return 'Network error. Please try again.';
  }
  // For other exceptions, return the message directly
  final msg = error.toString();
  // Remove common prefixes that make errors ugly
  if (msg.startsWith('Exception: ')) {
    return msg.substring(11);
  }
  return msg;
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  ApiClient? _apiClient;
  SecureStorage? _secureStorage;
  LocalStorage? _localStorage;
  Timer? _refreshTimer;
  bool _isInitialized = false;

  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckStatus>(_onCheckStatus);
    on<AuthLogin>(_onLogin);
    on<AuthRegister>(_onRegister);
    on<AuthLogout>(_onLogout);
    on<AuthUpdateUser>(_onUpdateUser);
    on<AuthRefreshToken>(_onRefreshToken);
    on<AuthTokenExpired>(_onTokenExpired);
    on<AuthForgotPassword>(_onForgotPassword);
    on<AuthResetPassword>(_onResetPassword);
    on<AuthVerifyEmail>(_onVerifyEmail);
    on<AuthResendVerification>(_onResendVerification);
    on<AuthClearError>(_onClearError);
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _apiClient = await ApiClient.getInstance();
    _secureStorage = await SecureStorage.getInstance();
    _localStorage = await LocalStorage.getInstance();
    _isInitialized = true;
  }

  // Getters that assert initialization
  ApiClient get _api => _apiClient!;
  SecureStorage get _secure => _secureStorage!;
  LocalStorage get _local => _localStorage!;

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    // Check token expiry every minute
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      final isExpired = await _secure.isTokenExpired();
      if (isExpired) {
        add(const AuthRefreshToken());
      }
    });
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await _secure.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _api.post(
        ApiConstants.refreshToken,
        data: {'refresh_token': refreshToken},
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = response.data;
        await _secure.saveAccessToken(data['access_token']);
        if (data['refresh_token'] != null) {
          await _secure.saveRefreshToken(data['refresh_token']);
        }
        if (data['expires_in'] != null) {
          await _secure.saveTokenExpiry(data['expires_in']);
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _onCheckStatus(
    AuthCheckStatus event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _initialize();

      final token = await _secure.getAccessToken();
      if (token == null) {
        emit(AuthUnauthenticated());
        return;
      }

      // Check if token is expired and try to refresh
      final isExpired = await _secure.isTokenExpired();
      if (isExpired) {
        final refreshed = await _tryRefreshToken();
        if (!refreshed) {
          await _secure.clearTokens();
          emit(AuthUnauthenticated());
          return;
        }
      }

      // Try to get current user
      final response = await _api
          .get(ApiConstants.userMe)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final user = UserModel.fromJson(response.data);
        await _local.saveUserData(response.data);
        if (user.teamId != null && user.teamId!.isNotEmpty) {
          await _secure.write('team_id', user.teamId!);
        }
        _startRefreshTimer();
        emit(AuthAuthenticated(user: user));
      } else {
        await _secure.clearTokens();
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      // Check for cached user data
      final cachedUser = _local.getUserData();
      if (cachedUser != null) {
        final user = UserModel.fromJson(cachedUser);
        if (user.teamId != null && user.teamId!.isNotEmpty) {
          await _secure.write('team_id', user.teamId!);
        }
        emit(AuthAuthenticated(user: user, isOffline: true));
      } else {
        emit(AuthUnauthenticated());
      }
    }
  }

  Future<void> _onLogin(AuthLogin event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    try {
      await _initialize();

      final response = await _api.post(
        ApiConstants.login,
        data: {'email': event.email, 'password': event.password},
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(response.data);

        // Save tokens
        await _secure.saveAccessToken(authResponse.accessToken);
        if (authResponse.refreshToken != null) {
          await _secure.saveRefreshToken(authResponse.refreshToken!);
        }

        // Save token expiry
        if (authResponse.expiresIn != null) {
          await _secure.saveTokenExpiry(authResponse.expiresIn!);
        }

        // Get user profile if not included in response
        UserModel user;
        if (authResponse.user != null) {
          user = authResponse.user!;
        } else {
          final userResponse = await _api.get(ApiConstants.userMe);
          user = UserModel.fromJson(userResponse.data);
        }

        await _local.saveUserData(user.toJson());
        if (user.teamId != null && user.teamId!.isNotEmpty) {
          await _secure.write('team_id', user.teamId!);
        }
        _startRefreshTimer();
        emit(AuthAuthenticated(user: user));
      } else {
        emit(
          AuthError(message: 'Login failed. Please check your credentials.'),
        );
      }
    } catch (e) {
      // Check if this is a specific error type
      final errorMessage = _extractErrorMessage(e);
      final errorLower = errorMessage.toLowerCase();

      // Check for email verification required
      if (errorLower.contains('verify your email') ||
          errorLower.contains('email verification') ||
          errorLower.contains('verification link')) {
        emit(
          AuthEmailVerificationRequired(
            message: errorMessage,
            email: event.email,
          ),
        );
      }
      // Check for pending approval (after email verification)
      else if (errorLower.contains('pending verification') ||
          errorLower.contains('pending admin approval') ||
          errorLower.contains('wait for admin approval') ||
          errorLower.contains('wait for approval') ||
          errorLower.contains('await approval')) {
        // Determine role from error message
        final isTeamLeader =
            errorLower.contains('admin approval') ||
            errorLower.contains('administrator');
        emit(
          AuthPendingVerification(
            message: errorMessage,
            role: isTeamLeader ? 'team_leader' : 'worker',
            email: event.email,
          ),
        );
      }
      // Check for account rejected
      else if (errorLower.contains('rejected') ||
          errorLower.contains('account has been rejected')) {
        // Try to extract rejection reason
        String? reason;
        final reasonMatch = RegExp(
          r'reason[:\s]+(.+)',
          caseSensitive: false,
        ).firstMatch(errorMessage);
        if (reasonMatch != null) {
          reason = reasonMatch.group(1)?.trim();
        }
        emit(
          AuthAccountRejected(
            message: errorMessage,
            reason: reason,
            email: event.email,
          ),
        );
      } else {
        emit(AuthError(message: errorMessage));
      }
    }
  }

  Future<void> _onRegister(AuthRegister event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    try {
      await _initialize();

      final response = await _api.post(
        ApiConstants.register,
        data: {
          'email': event.email,
          'password': event.password,
          'display_name': event.displayName,
          'role': event.role,
          if (event.firstName != null) 'first_name': event.firstName,
          if (event.lastName != null) 'last_name': event.lastName,
          // Workers select a team to request joining (team_id)
          if (event.role == 'worker' && event.teamId != null)
            'team_id': event.teamId,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;

        // Check if this is a pending verification response (no tokens)
        final accessToken = data['access_token']?.toString() ?? '';
        // verification_status can be at top level or inside user object
        final verificationStatus =
            data['verification_status'] ??
            (data['user'] as Map<String, dynamic>?)?['verification_status'];
        // Check if email verification is required
        // Handle both boolean and potential string values from API
        final rawEmailVerified =
            data['email_verified'] ??
            (data['user'] as Map<String, dynamic>?)?['email_verified'];
        final emailVerified =
            rawEmailVerified == true || rawEmailVerified == 'true';

        if (accessToken.isEmpty || verificationStatus == 'pending') {
          // Check if email verification is needed first (email NOT verified yet)
          if (!emailVerified) {
            // User registered but needs to verify email first
            debugPrint(
              '📧 Emitting AuthRegistrationSuccess for ${event.email}',
            );
            emit(
              AuthRegistrationSuccess(
                message:
                    data['message'] ??
                    'Registration successful! Please check your email to verify your account.',
                email: event.email,
                role: event.role,
              ),
            );
            debugPrint('📧 AuthRegistrationSuccess emitted');
            return;
          }

          // Email is verified but still pending approval
          String message;
          if (event.role == 'team_leader') {
            message =
                'Your account has been created and is pending verification by an admin. '
                'You will be able to login once your account is approved.';
          } else {
            message =
                'Your account has been created. '
                'You will be able to login once a team leader approves your join request.';
          }

          emit(
            AuthPendingVerification(
              message: data['message'] ?? message,
              role: event.role,
              email: event.email,
            ),
          );
          return;
        }

        // User can login immediately (has tokens)
        final authResponse = AuthResponse.fromJson(data);

        // Save tokens
        await _secure.saveAccessToken(authResponse.accessToken);
        if (authResponse.refreshToken != null) {
          await _secure.saveRefreshToken(authResponse.refreshToken!);
        }

        // Save token expiry
        if (authResponse.expiresIn != null) {
          await _secure.saveTokenExpiry(authResponse.expiresIn!);
        }

        // Get user profile
        UserModel user;
        if (authResponse.user != null) {
          user = authResponse.user!;
        } else {
          final userResponse = await _api.get(ApiConstants.userMe);
          user = UserModel.fromJson(userResponse.data);
        }

        await _local.saveUserData(user.toJson());
        if (user.teamId != null && user.teamId!.isNotEmpty) {
          await _secure.write('team_id', user.teamId!);
        }
        _startRefreshTimer();
        emit(AuthAuthenticated(user: user));
      } else {
        emit(AuthError(message: 'Registration failed. Please try again.'));
      }
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  Future<void> _onLogout(AuthLogout event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    try {
      await _initialize();
      _stopRefreshTimer();

      // Call logout endpoint (optional, token invalidation)
      try {
        await _api.post(ApiConstants.userLogout);
      } catch (_) {
        // Ignore logout API errors
      }

      // Clear local data
      await _secure.clearTokens();
      await _local.clearUserData();

      emit(AuthUnauthenticated());
    } catch (e) {
      // Still logout locally even if API fails
      await _secure.clearTokens();
      await _local.clearUserData();
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onUpdateUser(
    AuthUpdateUser event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is AuthAuthenticated) {
      await _local.saveUserData(event.user.toJson());
      emit(AuthAuthenticated(user: event.user));
    }
  }

  Future<void> _onRefreshToken(
    AuthRefreshToken event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is! AuthAuthenticated) return;

    final refreshed = await _tryRefreshToken();
    if (!refreshed) {
      add(const AuthTokenExpired());
    }
  }

  Future<void> _onTokenExpired(
    AuthTokenExpired event,
    Emitter<AuthState> emit,
  ) async {
    _stopRefreshTimer();
    await _secure.clearTokens();
    await _local.clearUserData();
    emit(AuthUnauthenticated());
  }

  Future<void> _onForgotPassword(
    AuthForgotPassword event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _initialize();

      final response = await _api.post(
        ApiConstants.forgotPassword,
        data: {'email': event.email},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        emit(
          AuthForgotPasswordSuccess(
            message:
                data['message'] ??
                'If an account exists with this email, a password reset link has been sent.',
            email: event.email,
          ),
        );
      } else {
        // Still show success to prevent email enumeration
        emit(
          AuthForgotPasswordSuccess(
            message:
                'If an account exists with this email, a password reset link has been sent.',
            email: event.email,
          ),
        );
      }
    } catch (e) {
      // Still show success to prevent email enumeration
      emit(
        AuthForgotPasswordSuccess(
          message:
              'If an account exists with this email, a password reset link has been sent.',
          email: event.email,
        ),
      );
    }
  }

  Future<void> _onResetPassword(
    AuthResetPassword event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _initialize();

      final response = await _api.post(
        ApiConstants.resetPassword,
        data: {'token': event.token, 'new_password': event.newPassword},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        emit(
          AuthPasswordResetSuccess(
            message:
                data['message'] ??
                'Password reset successfully. Please login with your new password.',
          ),
        );
      } else {
        emit(AuthError(message: 'Failed to reset password. Please try again.'));
      }
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  Future<void> _onVerifyEmail(
    AuthVerifyEmail event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _initialize();

      final response = await _api.post(
        ApiConstants.verifyEmail,
        data: {'token': event.token},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        emit(
          AuthEmailVerified(
            message:
                data['message'] ??
                'Email verified successfully. You can now await approval from the administrator.',
          ),
        );
      } else {
        emit(
          AuthError(
            message:
                'Failed to verify email. The link may be invalid or expired.',
          ),
        );
      }
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  Future<void> _onResendVerification(
    AuthResendVerification event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _initialize();

      final response = await _api.post(
        ApiConstants.resendVerification,
        data: {'email': event.email},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        emit(
          AuthResendVerificationSuccess(
            message:
                data['message'] ??
                'If an account exists with this email and is not yet verified, a verification email has been sent.',
          ),
        );
      } else {
        // Still show success to prevent email enumeration
        emit(
          AuthResendVerificationSuccess(
            message:
                'If an account exists with this email and is not yet verified, a verification email has been sent.',
          ),
        );
      }
    } catch (e) {
      // Still show success to prevent email enumeration
      emit(
        AuthResendVerificationSuccess(
          message:
              'If an account exists with this email and is not yet verified, a verification email has been sent.',
        ),
      );
    }
  }

  Future<void> _onClearError(
    AuthClearError event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthUnauthenticated());
  }

  @override
  Future<void> close() {
    _stopRefreshTimer();
    return super.close();
  }
}
