import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/user_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/constants/api_constants.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  ApiClient? _apiClient;
  SecureStorage? _secureStorage;
  bool _isInitialized = false;

  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckStatus>(_onCheckStatus);
    on<AuthLogin>(_onLogin);
    on<AuthLogout>(_onLogout);
    on<AuthForgotPassword>(_onForgotPassword);
    on<AuthResetPassword>(_onResetPassword);
    on<AuthClearError>(_onClearError);
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _apiClient = await ApiClient.getInstance();
    _secureStorage = await SecureStorage.getInstance();
    _isInitialized = true;
  }

  ApiClient get _api => _apiClient!;
  SecureStorage get _secure => _secureStorage!;

  Future<void> _onCheckStatus(AuthCheckStatus event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    try {
      await _initialize();

      final token = await _secure.getAccessToken();
      if (token == null) {
        emit(AuthUnauthenticated());
        return;
      }

      final role = await _secure.getUserRole();
      final email = await _secure.getUserEmail();
      final userId = await _secure.getUserId();

      if (role == null || (role != 'admin' && role != 'superadmin')) {
        await _secure.clearAll();
        emit(AuthUnauthenticated());
        return;
      }

      // Validate token by making an API call
      try {
        // Try to fetch admin stats to validate the token
        final response = await _api.get(ApiConstants.adminStats);
        if (response.statusCode == 200) {
          emit(AuthAuthenticated(
            user: UserModel(
              id: userId ?? '',
              email: email ?? '',
              role: role,
            ),
          ));
        } else {
          await _secure.clearAll();
          emit(AuthUnauthenticated());
        }
      } catch (e) {
        // If API call fails with 401, token is invalid
        print('[AuthBloc] Token validation failed: $e');
        await _secure.clearAll();
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      print('[AuthBloc] Check status error: $e');
      await _secure.clearAll();
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(AuthLogin event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    try {
      await _initialize();

      print('[AuthBloc] Attempting login for ${event.email}');
      final response = await _api.post(
        ApiConstants.login,
        data: {
          'email': event.email,
          'password': event.password,
        },
      );

      print('[AuthBloc] Response status: ${response.statusCode}');
      print('[AuthBloc] Response data type: ${response.data.runtimeType}');
      print('[AuthBloc] Response data: ${response.data}');

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(response.data);
        final user = authResponse.user;
        print('[AuthBloc] Parsed user: ${user?.email}, role: ${user?.role}');

        // Check if user is admin or superadmin
        if (user == null || (!user.isAdmin && !user.isSuperAdmin)) {
          emit(const AuthError(message: 'Access denied. Admin or Superadmin role required.'));
          return;
        }

        // Save tokens
        await _secure.saveAccessToken(authResponse.accessToken);
        if (authResponse.refreshToken != null) {
          await _secure.saveRefreshToken(authResponse.refreshToken!);
        }

        // Save user info
        await _secure.saveUserRole(user.role);
        await _secure.saveUserId(user.id);
        await _secure.saveUserEmail(user.email);

        emit(AuthAuthenticated(user: user));
      } else {
        emit(const AuthError(message: 'Login failed. Please check your credentials.'));
      }
    } catch (e, stackTrace) {
      print('[AuthBloc] Login error: $e');
      print('[AuthBloc] Stack trace: $stackTrace');
      String message = 'Login failed';
      if (e.toString().contains('401')) {
        message = 'Invalid email or password';
      } else if (e.toString().contains('403')) {
        message = 'Access denied. Admin role required.';
      }
      emit(AuthError(message: message));
    }
  }

  Future<void> _onLogout(AuthLogout event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _initialize();
      await _secure.clearAll();
      emit(AuthUnauthenticated());
    } catch (e) {
      await _secure.clearAll();
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onForgotPassword(AuthForgotPassword event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    try {
      await _initialize();

      final response = await _api.post(
        ApiConstants.forgotPassword,
        data: {'email': event.email},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        emit(AuthForgotPasswordSuccess(
          message: data['message'] ?? 'If an account exists with this email, a password reset link has been sent.',
          email: event.email,
        ));
      } else {
        // Still show success to prevent email enumeration
        emit(AuthForgotPasswordSuccess(
          message: 'If an account exists with this email, a password reset link has been sent.',
          email: event.email,
        ));
      }
    } catch (e) {
      // Still show success to prevent email enumeration
      emit(AuthForgotPasswordSuccess(
        message: 'If an account exists with this email, a password reset link has been sent.',
        email: event.email,
      ));
    }
  }

  Future<void> _onResetPassword(AuthResetPassword event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    try {
      await _initialize();

      final response = await _api.post(
        ApiConstants.resetPassword,
        data: {
          'token': event.token,
          'new_password': event.newPassword,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        emit(AuthPasswordResetSuccess(
          message: data['message'] ?? 'Password reset successfully. Please login with your new password.',
        ));
      } else {
        emit(const AuthError(message: 'Failed to reset password. Please try again.'));
      }
    } catch (e) {
      String message = 'Failed to reset password';
      if (e.toString().contains('invalid') || e.toString().contains('expired')) {
        message = 'Invalid or expired reset link. Please request a new one.';
      }
      emit(AuthError(message: message));
    }
  }

  Future<void> _onClearError(AuthClearError event, Emitter<AuthState> emit) async {
    emit(AuthUnauthenticated());
  }
}
