import 'package:equatable/equatable.dart';

/// Generic API Result wrapper for handling success and failure states
sealed class ApiResult<T> extends Equatable {
  const ApiResult();

  /// Factory constructor for success result
  const factory ApiResult.success(T data) = ApiSuccess<T>;

  /// Factory constructor for failure result
  const factory ApiResult.failure(String message, {int? statusCode, dynamic error}) = ApiFailure<T>;

  @override
  List<Object?> get props => [];
}

class ApiSuccess<T> extends ApiResult<T> {
  final T data;

  const ApiSuccess(this.data);

  @override
  List<Object?> get props => [data];
}

class ApiFailure<T> extends ApiResult<T> {
  final String message;
  final int? statusCode;
  final dynamic error;

  const ApiFailure(this.message, {this.statusCode, this.error});

  @override
  List<Object?> get props => [message, statusCode, error];
}

/// Extension methods for ApiResult
extension ApiResultExtension<T> on ApiResult<T> {
  bool get isSuccess => this is ApiSuccess<T>;
  bool get isFailure => this is ApiFailure<T>;

  T? get data => isSuccess ? (this as ApiSuccess<T>).data : null;
  String? get errorMessage => isFailure ? (this as ApiFailure<T>).message : null;

  R when<R>({
    required R Function(T data) success,
    required R Function(String message, int? statusCode) failure,
  }) {
    if (this is ApiSuccess<T>) {
      return success((this as ApiSuccess<T>).data);
    } else {
      final failure_ = this as ApiFailure<T>;
      return failure(failure_.message, failure_.statusCode);
    }
  }

  R maybeWhen<R>({
    R Function(T data)? success,
    R Function(String message, int? statusCode)? failure,
    required R Function() orElse,
  }) {
    if (this is ApiSuccess<T> && success != null) {
      return success((this as ApiSuccess<T>).data);
    } else if (this is ApiFailure<T> && failure != null) {
      final failure_ = this as ApiFailure<T>;
      return failure(failure_.message, failure_.statusCode);
    }
    return orElse();
  }

  ApiResult<R> map<R>(R Function(T data) mapper) {
    if (this is ApiSuccess<T>) {
      return ApiSuccess(mapper((this as ApiSuccess<T>).data));
    }
    final f = this as ApiFailure<T>;
    return ApiFailure<R>(f.message, statusCode: f.statusCode, error: f.error);
  }
}
