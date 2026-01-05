import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/user_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/constants/api_constants.dart';

part 'auth_event.dart';
part 'auth_state.dart';

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
      );

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

  Future<void> _onCheckStatus(AuthCheckStatus event, Emitter<AuthState> emit) async {
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
      final response = await _api.get(ApiConstants.userMe);
      if (response.statusCode == 200) {
        final user = UserModel.fromJson(response.data);
        await _local.saveUserData(response.data);
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
        data: {
          'email': event.email,
          'password': event.password,
        },
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
        _startRefreshTimer();
        emit(AuthAuthenticated(user: user));
      } else {
        emit(AuthError(message: 'Login failed. Please check your credentials.'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
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
          // Team leaders create a new team with team_name
          if (event.role == 'team_leader' && event.teamName != null)
            'team_name': event.teamName,
          // Workers can optionally join an existing team
          if (event.role == 'worker' && event.teamId != null)
            'team_id': event.teamId,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
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

        // Get user profile
        UserModel user;
        if (authResponse.user != null) {
          user = authResponse.user!;
        } else {
          final userResponse = await _api.get(ApiConstants.userMe);
          user = UserModel.fromJson(userResponse.data);
        }

        await _local.saveUserData(user.toJson());
        _startRefreshTimer();
        emit(AuthAuthenticated(user: user));
      } else {
        emit(AuthError(message: 'Registration failed. Please try again.'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
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

  Future<void> _onUpdateUser(AuthUpdateUser event, Emitter<AuthState> emit) async {
    final currentState = state;
    if (currentState is AuthAuthenticated) {
      await _local.saveUserData(event.user.toJson());
      emit(AuthAuthenticated(user: event.user));
    }
  }

  Future<void> _onRefreshToken(AuthRefreshToken event, Emitter<AuthState> emit) async {
    final currentState = state;
    if (currentState is! AuthAuthenticated) return;

    final refreshed = await _tryRefreshToken();
    if (!refreshed) {
      add(const AuthTokenExpired());
    }
  }

  Future<void> _onTokenExpired(AuthTokenExpired event, Emitter<AuthState> emit) async {
    _stopRefreshTimer();
    await _secure.clearTokens();
    await _local.clearUserData();
    emit(AuthUnauthenticated());
  }

  @override
  Future<void> close() {
    _stopRefreshTimer();
    return super.close();
  }
}
