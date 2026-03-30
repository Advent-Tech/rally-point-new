import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

/// API Client using Dio with interceptors for auth and logging
class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;
  SecureStorage? _storage;
  String? _authToken;
  bool _interceptorsConfigured = false;
  Future<bool>? _refreshInFlight;

  ApiClient._() {
    _dio = Dio(_baseOptions);
    // Trust self-signed certificates (EC2 uses self-signed SSL)
    if (!kIsWeb) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      };
    }
  }

  /// Unnamed constructor that returns the singleton instance synchronously
  /// Note: For full functionality, call initialize() after construction
  factory ApiClient() {
    _instance ??= ApiClient._();
    return _instance!;
  }

  static Future<ApiClient> getInstance() async {
    _instance ??= ApiClient._();
    if (_instance!._storage == null) {
      _instance!._storage = await SecureStorage.getInstance();
      _instance!._setupInterceptors();
    }
    return _instance!;
  }

  /// Initialize the API client with storage (call this early in app startup)
  Future<void> initialize() async {
    _storage ??= await SecureStorage.getInstance();
    _setupInterceptors();
  }

  Dio get dio => _dio;

  /// Set auth token for requests
  void setAuthToken(String token) {
    _authToken = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clear auth token
  void clearAuthToken() {
    _authToken = null;
    _dio.options.headers.remove('Authorization');
  }

  BaseOptions get _baseOptions => BaseOptions(
    baseUrl: _getBaseUrl(),
    connectTimeout: const Duration(
      milliseconds: ApiConstants.connectionTimeout,
    ),
    receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
    followRedirects: true,
    maxRedirects: 5,
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
  );

  String _getBaseUrl() {
    // Use localhost for web development.
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    // For mobile release builds, allow explicit API host override via dart-define.
    return ApiConstants.configuredBaseUrl;
  }

  void _setupInterceptors() {
    if (_interceptorsConfigured) return;
    _interceptorsConfigured = true;

    // Auth Interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage?.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          final isRefreshCall = error.requestOptions.path.contains(
            ApiConstants.refreshToken,
          );
          final alreadyRetried =
              error.requestOptions.extra['retried_after_refresh'] == true;

          if (!isRefreshCall &&
              !alreadyRetried &&
              error.response?.statusCode == 401) {
            // Try to refresh token
            final refreshed = await _refreshToken();
            if (refreshed) {
              // Retry the request
              final retryResponse = await _retryRequest(error.requestOptions);
              return handler.resolve(retryResponse);
            }
          }
          return handler.next(error);
        },
      ),
    );

    // Logging Interceptor (debug only) - body logging disabled for performance
    // Large responses (like geometry data) can cause 8000ms+ frame times when logged
    if (!kReleaseMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestHeader: false,
          requestBody: false,
          responseBody: false,
          responseHeader: false,
          error: true,
          logPrint: (obj) => debugPrint(obj.toString()),
        ),
      );
    }
  }

  Future<bool> _refreshToken() async {
    if (_refreshInFlight != null) {
      return _refreshInFlight!;
    }

    _refreshInFlight = _performRefresh();
    final result = await _refreshInFlight!;
    _refreshInFlight = null;
    return result;
  }

  Future<bool> _performRefresh() async {
    try {
      final refreshToken = await _storage?.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await Dio().post(
        '${_getBaseUrl()}${ApiConstants.refreshToken}',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await _storage?.saveAccessToken(data['access_token']);
        if (data['refresh_token'] != null) {
          await _storage?.saveRefreshToken(data['refresh_token']);
        }
        final expiresIn = data['expires_in'];
        if (expiresIn is int) {
          await _storage?.saveTokenExpiry(expiresIn);
        } else {
          await _storage?.saveTokenExpiry(60 * 60 * 24 * 30);
        }
        setAuthToken(data['access_token']);
        return true;
      }
    } catch (e) {
      debugPrint('Token refresh failed: $e');
    }
    return false;
  }

  Future<Response> _retryRequest(RequestOptions requestOptions) async {
    final token = await _storage?.getAccessToken();
    final options = Options(
      method: requestOptions.method,
      extra: {...requestOptions.extra, 'retried_after_refresh': true},
      headers: {...requestOptions.headers, 'Authorization': 'Bearer $token'},
    );
    return _dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  // HTTP Methods
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
}
