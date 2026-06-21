// Unit tests for ApiService error mapping (ApiError.from).
//
// The HTTP layer (Dio) itself is not tested here — that requires integration
// tests with a live or mock server. These tests focus on the pure error-mapping
// logic in ApiError.from, which is fully unit-testable.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wellnex_app/services/api_service.dart';

void main() {
  group('ApiError.from — passthrough', () {
    test('returns same ApiError when passed an ApiError', () {
      const original = ApiError(message: 'already an error', statusCode: 400);
      expect(ApiError.from(original), same(original));
    });
  });

  group('ApiError.from — DioException with response', () {
    DioException makeResponseError(
        int statusCode, dynamic body, DioExceptionType type) {
      final requestOptions = RequestOptions(path: '/test');
      final response = Response<dynamic>(
        requestOptions: requestOptions,
        statusCode: statusCode,
        data: body,
      );
      return DioException(
        requestOptions: requestOptions,
        response: response,
        type: type,
      );
    }

    test('extracts message from Map response body', () {
      final error = makeResponseError(
        422,
        {'message': 'Email already exists'},
        DioExceptionType.badResponse,
      );
      final apiError = ApiError.from(error);
      expect(apiError.message, contains('Email already exists'));
      expect(apiError.statusCode, 422);
    });

    test('uses String response body as message', () {
      final error = makeResponseError(
        500,
        'Internal Server Error',
        DioExceptionType.badResponse,
      );
      final apiError = ApiError.from(error);
      expect(apiError.message, contains('Internal Server Error'));
    });

    test('falls back to generic message when body is null', () {
      final error = makeResponseError(
        503,
        null,
        DioExceptionType.badResponse,
      );
      final apiError = ApiError.from(error);
      expect(apiError.message, isNotEmpty);
      expect(apiError.statusCode, 503);
    });
  });

  group('ApiError.from — DioException without response', () {
    DioException makeNetworkError(DioExceptionType type) {
      return DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: type,
      );
    }

    test('maps connectionTimeout to timeout message', () {
      final error = makeNetworkError(DioExceptionType.connectionTimeout);
      final apiError = ApiError.from(error);
      expect(apiError.message.toLowerCase(), contains('timed out'));
      expect(apiError.statusCode, isNull);
    });

    test('maps connectionError to connection message', () {
      final error = makeNetworkError(DioExceptionType.connectionError);
      final apiError = ApiError.from(error);
      expect(apiError.message.toLowerCase(), contains('connection'));
    });

    test('maps badCertificate to security message', () {
      final error = makeNetworkError(DioExceptionType.badCertificate);
      final apiError = ApiError.from(error);
      expect(apiError.message.toLowerCase(), contains('security'));
    });

    test('maps cancel to cancelled message', () {
      final error = makeNetworkError(DioExceptionType.cancel);
      final apiError = ApiError.from(error);
      expect(apiError.message.toLowerCase(), contains('cancel'));
    });
  });

  group('ApiError.from — generic exceptions', () {
    test('maps NoSuchMethodError to application error message', () {
      final error = Exception('NoSuchMethodError: something went wrong');
      final apiError = ApiError.from(error);
      expect(apiError.message,
          'An unexpected application error occurred. Please try again.');
    });

    test('maps FormatException to application error message', () {
      final error = Exception('FormatException: invalid date');
      final apiError = ApiError.from(error);
      expect(apiError.message,
          'An unexpected application error occurred. Please try again.');
    });

    test('strips "Exception: " prefix from generic errors', () {
      final error = Exception('Something custom went wrong');
      final apiError = ApiError.from(error);
      expect(apiError.message, 'Something custom went wrong');
    });
  });

  group('ApiError — toString', () {
    test('toString returns the message', () {
      const error = ApiError(message: 'Some error');
      expect(error.toString(), 'Some error');
    });
  });

  group('ApiError.fromDioError — backward compat', () {
    test('delegates to ApiError.from', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.cancel,
      );
      final a = ApiError.from(dioError);
      final b = ApiError.fromDioError(dioError);
      expect(a.message, b.message);
    });
  });
}
