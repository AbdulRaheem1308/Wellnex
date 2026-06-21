import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wellnex_app/services/api_service.dart';
import 'package:wellnex_app/services/company_service.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockApiService mockApi;
  late CompanyService service;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    mockApi = MockApiService();
    service = CompanyService(mockApi);
  });

  group('CompanyService', () {
    const mockCompanyId = 'comp_123';
    const mockMemberData = {
      'id': 'mem_1',
      'userId': 'usr_1',
      'companyId': mockCompanyId,
      'role': 'MEMBER',
      'totalSteps': 1000,
      'company': {
        'id': mockCompanyId,
        'name': 'Test Corp',
        'inviteCode': 'TEST12',
      },
      'user': {
        'id': 'usr_1',
        'name': 'Test User',
      }
    };

    test('joinCompany returns CompanyMember on success', () async {
      when(() => mockApi.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: mockMemberData,
        ),
      );

      final result = await service.joinCompany('TEST12');

      expect(result.id, 'mem_1');
      expect(result.companyId, mockCompanyId);
      verify(() => mockApi.post('/companies/TEST12/join', data: {})).called(1);
    });

    test('joinCompany throws ApiError on failure', () async {
      when(() => mockApi.post(any(), data: any(named: 'data'))).thenThrow(Exception('error'));

      expect(() => service.joinCompany('TEST12'), throwsA(isA<ApiError>()));
    });

    test('getMyCompany returns CompanyMember if found', () async {
      when(() => mockApi.get(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: mockMemberData,
        ),
      );

      final result = await service.getMyCompany();

      expect(result, isNotNull);
      expect(result!.id, 'mem_1');
      verify(() => mockApi.get('/companies/my-company/me')).called(1);
    });

    test('getMyCompany returns null if data is empty string', () async {
      when(() => mockApi.get(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: '',
        ),
      );

      final result = await service.getMyCompany();

      expect(result, isNull);
    });

    test('getMyCompany returns null if 404', () async {
      when(() => mockApi.get(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(requestOptions: RequestOptions(path: ''), statusCode: 404),
      ));

      final result = await service.getMyCompany();

      expect(result, isNull);
    });

    test('getMyCompany throws ApiError on other errors', () async {
      when(() => mockApi.get(any())).thenThrow(Exception('error'));

      expect(() => service.getMyCompany(), throwsA(isA<ApiError>()));
    });

    test('getLeaderboard returns list of members', () async {
      when(() => mockApi.get(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: [mockMemberData],
        ),
      );

      final result = await service.getLeaderboard(mockCompanyId);

      expect(result.length, 1);
      expect(result.first.id, 'mem_1');
      verify(() => mockApi.get('/companies/$mockCompanyId/leaderboard')).called(1);
    });

    test('getLeaderboard throws ApiError on failure', () async {
      when(() => mockApi.get(any())).thenThrow(Exception('error'));

      expect(() => service.getLeaderboard(mockCompanyId), throwsA(isA<ApiError>()));
    });
  });
}
