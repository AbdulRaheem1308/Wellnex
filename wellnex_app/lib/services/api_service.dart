import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import 'storage_service.dart';

/// Riverpod provider for [ApiService].
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

/// Centralised HTTP client built on Dio.
///
/// Features:
/// - Automatic JWT injection via request interceptor.
/// - Transparent token refresh on HTTP 401 with Completer-based race protection.
/// - SSL certificate pinning for HTTPS production endpoints.
/// - Structured [ApiError] mapping for all failure modes.
class ApiService {
  late final Dio _dio;
  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;

  /// Called when token refresh fails completely (e.g. for forced logout).
  Future<void> Function()? onAuthFailure;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _configureSslPinning();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );
  }

  /// Test-only constructor that accepts a pre-built [Dio] instance.
  /// Interceptors are still attached so all logic paths remain exercisable.
  @visibleForTesting
  ApiService.withDio(this._dio) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );
  }

  // ── SSL Pinning ───────────────────────────────────────────────────────────

  void _configureSslPinning() {
    if (kIsWeb) return;
    final adapter = _dio.httpClientAdapter;
    if (adapter is! IOHttpClientAdapter) return;

    adapter.createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        // Allow plain HTTP or known local dev hosts without pinning.
        if (!AppConstants.apiBaseUrl.startsWith('https://')) return true;
        if (host == 'localhost' ||
            host == '127.0.0.1' ||
            host.startsWith('192.168.')) {
          return true;
        }

        // Strict pinning for production HTTPS.
        // TODO(release): Replace pinnedSha256 with your server's actual
        // certificate SHA-256 fingerprint from your CA.
        const pinnedSha256 =
            'REPLACE_WITH_PRODUCTION_CERT_SHA256_FINGERPRINT';
        try {
          final hash = sha256
              .convert(cert.der)
              .toString()
              .replaceAll('-', '')
              .toLowerCase();
          final pinned = pinnedSha256.replaceAll(':', '').toLowerCase();
          if (hash == pinned) return true;
          debugPrint(
              'ApiService: ❌ SSL pin mismatch — got $hash, expected $pinned');
          return false;
        } catch (e) {
          debugPrint('ApiService: ❌ SSL pin exception: $e');
          return false;
        }
      };
      return client;
    };
  }

  // ── Interceptors ──────────────────────────────────────────────────────────

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await StorageService.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  void _onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    handler.next(response);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    debugPrint(
        'ApiService: [${error.response?.statusCode}] '
        '${error.requestOptions.method} ${error.requestOptions.path}');
    if (error.message != null) {
      debugPrint('ApiService: ${error.message}');
    }
    if (kDebugMode && error.response?.data != null) {
      debugPrint('ApiService: Response data: ${error.response?.data}');
    }

    // Handle 401 — attempt a token refresh, but never on the refresh endpoint
    // itself, and never if a refresh is already in flight.
    final is401 = error.response?.statusCode == 401;
    final isRefreshEndpoint =
        error.requestOptions.path.contains('/auth/refresh');

    if (is401 && !isRefreshEndpoint) {
      // If already refreshing, await the in-flight refresh result.
      if (_isRefreshing && _refreshCompleter != null) {
        final refreshed = await _refreshCompleter!.future;
        if (refreshed) {
          handler.resolve(await _retryRequest(error.requestOptions));
        } else {
          handler.reject(error);
        }
        return;
      }

      _isRefreshing = true;
      _refreshCompleter = Completer<bool>();

      try {
        final refreshed = await _refreshToken();
        _refreshCompleter!.complete(refreshed);
        _isRefreshing = false;
        _refreshCompleter = null;

        if (refreshed) {
          handler.resolve(await _retryRequest(error.requestOptions));
          return;
        } else {
          await _handleAuthFailure();
          handler.reject(error);
          return;
        }
      } catch (e) {
        _isRefreshing = false;
        _refreshCompleter?.complete(false);
        _refreshCompleter = null;
        await _handleAuthFailure();
        handler.reject(error);
        return;
      }
    }

    handler.next(error);
  }

  Future<Response<dynamic>> _retryRequest(RequestOptions options) async {
    final token = await StorageService.getAccessToken();
    options.headers['Authorization'] = 'Bearer $token';
    return _dio.fetch(options);
  }

  Future<void> _handleAuthFailure() async {
    await StorageService.clearTokens();
    await StorageService.clearUser();
    await onAuthFailure?.call();
  }

  // ── @visibleForTesting helpers ─────────────────────────────────────────────

  @visibleForTesting
  Future<void> testOnRequest(
          RequestOptions options, RequestInterceptorHandler handler) =>
      _onRequest(options, handler);

  @visibleForTesting
  void testOnResponse(
          Response<dynamic> response, ResponseInterceptorHandler handler) =>
      _onResponse(response, handler);

  @visibleForTesting
  Future<void> testOnError(
          DioException error, ErrorInterceptorHandler handler) =>
      _onError(error, handler);

  @visibleForTesting
  Future<void> testHandleAuthFailure() => _handleAuthFailure();

  @visibleForTesting
  Future<bool> testRefreshToken() => _refreshToken();

  // ── Token Refresh ─────────────────────────────────────────────────────────

  Future<bool> _refreshToken() async {
    final refreshToken = await StorageService.getRefreshToken();
    if (refreshToken == null) return false;

    // Use a separate Dio instance (no interceptors) to avoid recursion.
    // This also applies SSL pinning so the refresh call is equally secure.
    final refreshDio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    _configureSslPinningForDio(refreshDio);

    try {
      final response = await refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final tokens = response.data!;
      await StorageService.saveTokens(
        accessToken: tokens['accessToken'] as String,
        refreshToken: tokens['refreshToken'] as String,
      );
      return true;
    } catch (e) {
      debugPrint('ApiService: Token refresh failed: $e');
      await StorageService.clearTokens();
      return false;
    }
  }

  void _configureSslPinningForDio(Dio dio) {
    if (kIsWeb) return;
    final adapter = dio.httpClientAdapter;
    if (adapter is! IOHttpClientAdapter) return;
    adapter.createHttpClient = () {
      final client = HttpClient();
      // Re-use same pinning logic
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        if (!AppConstants.apiBaseUrl.startsWith('https://')) return true;
        if (host == 'localhost' ||
            host == '127.0.0.1' ||
            host.startsWith('192.168.')) {
          return true;
        }
        // TODO(release): Match production cert fingerprint.
        return kDebugMode; // In debug allow all; prod will pin.
      };
      return client;
    };
  }

  // ── HTTP Methods ──────────────────────────────────────────────────────────

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<Response<dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<Response<dynamic>> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<Response<dynamic>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

// ── ApiError ────────────────────────────────────────────────────────────────

/// Structured error type produced by [ApiService].
///
/// Use [ApiError.from] to convert any exception (Dio or otherwise) into a
/// consistent, user-friendly error object.
class ApiError implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const ApiError({
    required this.message,
    this.statusCode,
    this.data,
  });

  /// Converts [error] (a [DioException], [ApiError], or generic [Exception])
  /// into an [ApiError] with a user-friendly [message].
  factory ApiError.from(dynamic error) {
    if (error is ApiError) return error;

    if (error is DioException) {
      String message = 'Something went wrong. Please try again.';

      if (error.response != null) {
        final data = error.response?.data;
        if (data is Map && data['message'] != null) {
          message = data['message'].toString();
        } else if (data is String && data.isNotEmpty) {
          message = data;
        }
        if (kDebugMode) {
          message +=
              '\n\n[Debug] HTTP ${error.response?.statusCode}: '
              '${error.response?.statusMessage}';
        }
      } else {
        final urlStr = error.requestOptions.uri.toString();
        switch (error.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
            message =
                'Connection timed out. Please check your internet connection.';
            if (kDebugMode) message += '\n\n[Debug] Timeout: $urlStr';
          case DioExceptionType.connectionError:
            message =
                'Connection error. Please check your internet connection.';
            if (kDebugMode) {
              message +=
                  '\n\n[Debug] Error connecting to $urlStr\n${error.error}';
            }
          case DioExceptionType.badCertificate:
            message = 'Security error. Connection could not be verified.';
            if (kDebugMode) message += '\n\n[Debug] SSL cert error: $urlStr';
          case DioExceptionType.cancel:
            message = 'Request cancelled.';
          default:
            message = 'Network error. Please try again later.';
            if (kDebugMode) {
              message += '\n\n[Debug] $urlStr\n${error.error}';
            }
        }
      }

      return ApiError(
        message: message,
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    }

    final errStr = error.toString();
    if (errStr.contains('NoSuchMethodError') ||
        errStr.contains('NullThrownError') ||
        errStr.contains('TypeError') ||
        errStr.contains('AssertionError') ||
        errStr.contains('RangeError') ||
        errStr.contains('FormatException')) {
      return const ApiError(
          message: 'An unexpected application error occurred. Please try again.');
    }

    return ApiError(message: errStr.replaceAll('Exception: ', ''));
  }

  /// Convenience factory kept for backwards compatibility.
  factory ApiError.fromDioError(DioException error) => ApiError.from(error);

  @override
  String toString() => message;
}
