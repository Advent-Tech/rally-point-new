import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  static ApiClient? _instance;
  late Dio _dio;
  late SecureStorage _secureStorage;

  // Callback for when auth fails completely (both tokens invalid)
  static Function? onAuthFailure;

  ApiClient._internal();

  static Future<ApiClient> getInstance() async {
    if (_instance == null) {
      _instance = ApiClient._internal();
      await _instance!._init();
    }
    return _instance!;
  }

  // Set the auth failure callback
  static void setAuthFailureCallback(Function callback) {
    onAuthFailure = callback;
  }

  Future<void> _init() async {
    _secureStorage = await SecureStorage.getInstance();

    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 90),
        followRedirects: true,
        maxRedirects: 5,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            print('[API] Request to ${options.path} with token: ${token.substring(0, 20)}...');
          } else {
            print('[API] Request to ${options.path} WITHOUT token!');
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          print('[API] Error on ${error.requestOptions.path}: ${error.type} - ${error.response?.statusCode} - ${error.message}');
          print('[API] Error details: ${error.response?.data ?? error.error}');
          if (error.response?.statusCode == 401) {
            // Try to refresh token
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              // Retry the request
              final opts = error.requestOptions;
              final token = await _secureStorage.getAccessToken();
              opts.headers['Authorization'] = 'Bearer $token';
              try {
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              } catch (e) {
                return handler.next(error);
              }
            } else {
              // Both tokens are invalid, trigger auth failure callback
              print('[API] Auth failed completely - both tokens invalid');
              await _secureStorage.clearAll();
              if (onAuthFailure != null) {
                onAuthFailure!();
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await Dio().post(
        '${ApiConstants.baseUrl}${ApiConstants.refreshToken}',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await _secureStorage.saveAccessToken(data['access_token']);
        if (data['refresh_token'] != null) {
          await _secureStorage.saveRefreshToken(data['refresh_token']);
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response> postMultipart(
    String path,
    Map<String, dynamic> fields, {
    CancelToken? cancelToken,
  }) async {
    final formData = FormData();

    for (final entry in fields.entries) {
      if (entry.value is MultipartFileData) {
        final fileData = entry.value as MultipartFileData;
        formData.files.add(MapEntry(
          entry.key,
          MultipartFile.fromBytes(
            fileData.bytes,
            filename: fileData.filename,
          ),
        ));
      } else {
        formData.fields.add(MapEntry(entry.key, entry.value.toString()));
      }
    }

    return _dio.post(
      path,
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
      cancelToken: cancelToken,
    );
  }
}

// Helper class for multipart file upload
class MultipartFileData {
  final List<int> bytes;
  final String filename;

  MultipartFileData({required this.bytes, required this.filename});
}
