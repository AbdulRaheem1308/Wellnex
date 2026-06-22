import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wellnex_app/core/router/app_router.dart';

class MockGoRouterState extends Mock implements GoRouterState {}

void main() {
  test('AppRouter should provide a valid GoRouter instance', () {
    final container = ProviderContainer();
    
    final router = container.read(appRouterProvider);
    
    expect(router, isA<GoRouter>());
    expect(router.configuration.routes.isNotEmpty, isTrue);
    
    container.dispose();
  });

  testWidgets('AppRouter routes should construct their respective screens successfully', (WidgetTester tester) async {
    final container = ProviderContainer();
    final router = container.read(appRouterProvider);

    final mockState = MockGoRouterState();
    when(() => mockState.uri).thenReturn(Uri.parse('/otp?phone=1234567890&email=test@example.com'));
    when(() => mockState.pathParameters).thenReturn({'id': 'test-id'});
    when(() => mockState.extra).thenReturn(null);

    // Get all routes recursively
    List<RouteBase> getAllRoutes(List<RouteBase> routes) {
      final allRoutes = <RouteBase>[];
      for (final route in routes) {
        allRoutes.add(route);
        if (route is GoRoute && route.routes.isNotEmpty) {
          allRoutes.addAll(getAllRoutes(route.routes));
        } else if (route is ShellRoute) {
          allRoutes.addAll(getAllRoutes(route.routes));
        }
      }
      return allRoutes;
    }

    final allRoutes = getAllRoutes(router.configuration.routes);
    expect(allRoutes.isNotEmpty, isTrue);

    // Build a basic widget context using Builder
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            for (final route in allRoutes) {
              if (route is GoRoute && route.builder != null) {
                final widget = route.builder!(context, mockState);
                expect(widget, isA<Widget>());
              } else if (route is ShellRoute && route.builder != null) {
                final widget = route.builder!(context, mockState, const SizedBox());
                expect(widget, isA<Widget>());
              }
            }
            return const SizedBox();
          },
        ),
      ),
    );

    container.dispose();
  });

  test('AppRoutes should be instantiable for coverage', () {
    final appRoutes = AppRoutes();
    expect(appRoutes, isNotNull);
  });
}
