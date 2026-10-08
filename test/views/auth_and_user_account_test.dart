import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/data/repositories/mock_trip_repository.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/auth/auth_gate.dart';
import 'package:trippy/views/auth/sign_in_screen.dart';
import 'package:trippy/views/common/app_nav_scaffold.dart';
import 'package:trippy/views/common/user_account_button.dart';

void main() {
  group('Auth & User Account Tests', () {
    testWidgets('SignInScreen renders branding, Google and Guest buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SignInScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trippy'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
    });

    testWidgets('SignInScreen displays error banner when initialError is passed',
        (WidgetTester tester) async {
      const errorMsg = 'Google sign-in was cancelled';
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SignInScreen(initialError: errorMsg),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(errorMsg), findsOneWidget);
    });

    testWidgets('UserAccountButton renders and displays tooltip',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                actions: const [UserAccountButton()],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UserAccountButton), findsOneWidget);
      expect(find.byTooltip('Account'), findsOneWidget);
    });

    testWidgets('AuthGate routes directly to AppNavScaffold in mock mode',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(MockTripRepository()),
          ],
          child: const MaterialApp(
            home: AuthGate(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppNavScaffold), findsOneWidget);
    });

    test('effectiveActiveTripIdProvider defaults to first available trip when explicit id is null', () {
      final container = ProviderContainer(
        overrides: [
          tripRepositoryProvider.overrideWithValue(MockTripRepository()),
          currentUserIdProvider.overrideWithValue('user_current'),
        ],
      );
      addTearDown(container.dispose);

      // In mock repository, default trip is trip_japan_2026
      expect(container.read(effectiveActiveTripIdProvider), 'trip_japan_2026');

      // If user explicitly selects another trip, it updates
      container.read(activeTripIdProvider.notifier).selectTrip('trip_iceland_2027');
      expect(container.read(effectiveActiveTripIdProvider), 'trip_iceland_2027');
    });
  });
}
