import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/storage/secure_storage.dart';
import '../models/user_model.dart';

class AuthRepository {
  ApiClient? _apiClient;
  SecureStorage? _secureStorage;

  AuthRepository();

  Future<ApiClient> get apiClient async {
    _apiClient ??= await ApiClient.getInstance();
    return _apiClient!;
  }

  Future<SecureStorage> get secureStorage async {
    _secureStorage ??= await SecureStorage.getInstance();
    return _secureStorage!;
  }

  Future<ApiResult<AuthResponse>> login({
    required String email,
    required String password,
  }) async {
    try {
      final client = await apiClient;
      final storage = await secureStorage;

      final response = await client.dio.post(
        ApiConstants.login,
        data: {
          'email': email,
          'password': password,
        },
      );

      final authResponse = AuthResponse.fromJson(response.data);

      // Save tokens
      await storage.saveAccessToken(authResponse.accessToken);
      if (authResponse.refreshToken != null) {
        await storage.saveRefreshToken(authResponse.refreshToken!);
      }

      // Update API client with new token
      client.setAuthToken(authResponse.accessToken);

      return ApiResult.success(authResponse);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('An unexpected error occurred');
    }
  }

  Future<ApiResult<AuthResponse>> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final client = await apiClient;
      final storage = await secureStorage;

      final response = await client.dio.post(
        ApiConstants.register,
        data: {
          'email': email,
          'password': password,
          'displayName': displayName,
        },
      );

      final authResponse = AuthResponse.fromJson(response.data);

      // Save tokens
      await storage.saveAccessToken(authResponse.accessToken);
      if (authResponse.refreshToken != null) {
        await storage.saveRefreshToken(authResponse.refreshToken!);
      }

      // Update API client with new token
      client.setAuthToken(authResponse.accessToken);

      return ApiResult.success(authResponse);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('An unexpected error occurred');
    }
  }

  Future<ApiResult<UserModel>> getCurrentUser() async {
    try {
      final client = await apiClient;
      final storage = await secureStorage;

      // First try to load token from storage
      final token = await storage.getAccessToken();
      if (token == null) {
        return const ApiResult.failure('No auth token found');
      }

      client.setAuthToken(token);

      final response = await client.dio.get(ApiConstants.currentUser);
      final user = UserModel.fromJson(response.data);

      return ApiResult.success(user);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('An unexpected error occurred');
    }
  }

  Future<ApiResult<UserModel>> updateProfile({
    String? displayName,
    String? avatarUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final client = await apiClient;

      final data = <String, dynamic>{};
      if (displayName != null) data['displayName'] = displayName;
      if (avatarUrl != null) data['avatarUrl'] = avatarUrl;
      if (metadata != null) data['metadata'] = metadata;

      final response = await client.dio.put(
        ApiConstants.updateProfile,
        data: data,
      );

      final user = UserModel.fromJson(response.data);
      return ApiResult.success(user);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('An unexpected error occurred');
    }
  }

  Future<ApiResult<void>> logout() async {
    try {
      final client = await apiClient;
      final storage = await secureStorage;

      // Call logout endpoint if available
      try {
        await client.dio.post(ApiConstants.logout);
      } catch (_) {
        // Ignore logout endpoint errors
      }

      // Clear local storage
      await storage.clearTokens();
      client.clearAuthToken();

      return const ApiResult.success(null);
    } catch (e) {
      // Still try to clear tokens even if something fails
      try {
        final storage = await secureStorage;
        final client = await apiClient;
        await storage.clearTokens();
        client.clearAuthToken();
      } catch (_) {}
      return const ApiResult.success(null);
    }
  }

  Future<ApiResult<AuthResponse>> refreshToken() async {
    try {
      final client = await apiClient;
      final storage = await secureStorage;

      final refreshTokenValue = await storage.getRefreshToken();
      if (refreshTokenValue == null) {
        return const ApiResult.failure('No refresh token found');
      }

      final response = await client.dio.post(
        ApiConstants.refreshToken,
        data: {'refresh_token': refreshTokenValue},
      );

      final authResponse = AuthResponse.fromJson(response.data);

      // Save new tokens
      await storage.saveAccessToken(authResponse.accessToken);
      if (authResponse.refreshToken != null) {
        await storage.saveRefreshToken(authResponse.refreshToken!);
      }
      if (authResponse.expiresIn != null) {
        await storage.saveTokenExpiry(authResponse.expiresIn!);
      } else {
        await storage.saveTokenExpiry(60 * 60 * 24 * 30);
      }

      // Update API client with new token
      client.setAuthToken(authResponse.accessToken);

      return ApiResult.success(authResponse);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('An unexpected error occurred');
    }
  }

  Future<bool> isAuthenticated() async {
    final storage = await secureStorage;
    final token = await storage.getAccessToken();
    return token != null;
  }

  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;

        if (statusCode == 401) {
          return 'Invalid email or password';
        } else if (statusCode == 403) {
          return 'Access denied';
        } else if (statusCode == 404) {
          return 'User not found';
        } else if (statusCode == 409) {
          return 'Email already registered';
        } else if (statusCode == 422) {
          if (data is Map && data['message'] != null) {
            return data['message'];
          }
          return 'Invalid input data';
        } else if (statusCode == 500) {
          return 'Server error. Please try again later.';
        }

        if (data is Map && data['message'] != null) {
          return data['message'];
        }
        return 'An error occurred (Status: $statusCode)';
      case DioExceptionType.cancel:
        return 'Request cancelled';
      case DioExceptionType.connectionError:
        return 'No internet connection';
      default:
        return 'An unexpected error occurred';
    }
  }
}
