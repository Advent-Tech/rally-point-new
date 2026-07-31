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
  Future<bool>? _refreshFuture;

  /// Tracks which request paths have already been retried after a refresh,
  /// so concurrent 401s on the same endpoint don't double-retry.
  final Set<String> _retriedPaths = {};

  /// Global cancel token — cancelled on logout to abort all in-flight requests.
  CancelToken? _globalCancelToken;

  /// Called when a 401 cannot be recovered (refresh failed).
  /// AuthBloc sets this to trigger logout + redirect to login.
  VoidCallback? onAuthFailed;

  ApiClient._() {
    _dio = Dio(_baseOptions);
    // DEV ONLY: trust self-signed certificates.
    // Never allow this in release builds.
    if (!kIsWeb && !kReleaseMode) {
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
        connectTimeout: const Duration(milliseconds: ApiConstants.connectionTimeout),
        receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
        followRedirects: true,
        maxRedirects: 5,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
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
    // Auth Interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage?.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final path = error.requestOptions.path;

          // Prevent retry loops: only retry each endpoint once per refresh cycle
          if (_retriedPaths.contains(path)) {
            _retriedPaths.clear();
            debugPrint('ApiClient: already retried $path, propagating 401');
            return handler.next(error);
          }

          // Try to refresh token (shared future — only one refresh at a time)
          final refreshed = await refreshToken();
          if (refreshed) {
            _retriedPaths.add(path);
            // Retry the request with the new token
            final retryResponse = await _retryRequest(error.requestOptions);
            _retriedPaths.clear();
            return handler.resolve(retryResponse);
          }

          // Refresh failed — call onAuthFailed callback and propagate 401
          debugPrint('ApiClient: refresh failed, propagating 401');
          _retriedPaths.clear();
          onAuthFailed?.call();
        }
        return handler.next(error);
      },
    ));

    // Logging Interceptor (debug only) - body logging disabled for performance
    // Large responses (like geometry data) can cause 8000ms+ frame times when logged
    if (!kReleaseMode) {
      _dio.interceptors.add(LogInterceptor(
        requestHeader: false,
        requestBody: false,
        responseBody: false,
        responseHeader: false,
        error: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }
  }

  /// Refresh the access token using the refresh token.
  /// Uses a shared future to prevent concurrent refreshes (Fix 1).
  /// This is the single source of truth for token refresh — both the
  /// 401 interceptor and AuthBloc's timer call this method.
  Future<bool> refreshToken() async {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    _refreshFuture = _performRefresh();
    try {
      return await _refreshFuture!;
    } finally {
      _refreshFuture = null;
    }
  }

  /// Cancel all in-flight requests (called on logout).
  void cancelAllRequests() {
    _globalCancelToken?.cancel('User logged out');
    _globalCancelToken = CancelToken();
  }

  /// Get the current global cancel token, creating one if needed.
  CancelToken get cancelToken {
    _globalCancelToken ??= CancelToken();
    return _globalCancelToken!;
  }

  Future<bool> _performRefresh() async {
    try {
      final refreshToken = await _storage?.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await Dio(
        BaseOptions(
          connectTimeout: const Duration(milliseconds: ApiConstants.connectionTimeout),
          receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
        ),
      ).post(
        '${_getBaseUrl()}${ApiConstants.refreshToken}',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await _storage?.saveAccessToken(data['access_token']);
        if (data['refresh_token'] != null) {
          await _storage?.saveRefreshToken(data['refresh_token']);
        }
        // Always save expiry — default to 900s if backend omits it
        final expiresInRaw = data['expires_in'] ?? 900;
        final expiresIn = expiresInRaw is int
            ? expiresInRaw
            : int.tryParse(expiresInRaw.toString()) ?? 900;
        await _storage?.saveTokenExpiry(expiresIn);
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
      headers: {
        ...requestOptions.headers,
        'Authorization': 'Bearer $token',
      },
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
