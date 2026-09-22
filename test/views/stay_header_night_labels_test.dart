import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/views/logistics/widgets/stay_header_bridge_widget.dart';

void main() {
  group('StayHeaderBridgeWidget Outside Top Night Labels Tests', () {
    testWidgets('Renders outside top night labels centered in each segment for 2-night stay',
        (WidgetTester tester) async {
      final stay = Stay(
        id: 'stay_test_2n',
        tripId: 'trip_test',
        type: StayType.hotel,
        name: 'Grand Hyatt Tokyo',
        checkInDate: DateTime(2026, 10, 10),
        checkInTime: '15:00',
        checkOutDate: DateTime(2026, 10, 12),
        checkOutTime: '11:00',
        confirmationCode: 'GH-8821',
      );

      const double totalWidth = 600.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StayHeaderBridgeWidget(
              stay: stay,
              width: totalWidth,
              spanDays: 2,
            ),
          ),
        ),
      );

      // Verify night labels exist outside the rectangle
      final night1Finder = find.text('Night 1');
      final night2Finder = find.text('Night 2');
      expect(night1Finder, findsOneWidget);
      expect(night2Finder, findsOneWidget);

      // Verify the stay header title and details are present inside the rectangle
      expect(find.text('Grand Hyatt Tokyo'), findsOneWidget);
      expect(find.text('HOTEL • 2N'), findsOneWidget);

      // Verify horizontal positions: Night 1 is centered in [0, 300] => ~150
      // Night 2 is centered in [300, 600] => ~450
      final Offset night1Center = tester.getCenter(night1Finder);
      final Offset night2Center = tester.getCenter(night2Finder);

      // Segment 1 center: 0.5 * 300 = 150
      expect(night1Center.dx, closeTo(150.0, 5.0));
      // Segment 2 center: 1.5 * 300 = 450
      expect(night2Center.dx, closeTo(450.0, 5.0));

      // Both night labels should be in the top area (Y < 20)
      final Offset widgetTopLeft = tester.getTopLeft(find.byType(StayHeaderBridgeWidget));
      expect(night1Center.dy - widgetTopLeft.dy, lessThan(20.0));
      expect(night2Center.dy - widgetTopLeft.dy, lessThan(20.0));
    });

    testWidgets('Renders single night stay with centered Night 1 label on top',
        (WidgetTester tester) async {
      final stay = Stay(
        id: 'stay_test_1n',
        tripId: 'trip_test',
        type: StayType.hotel,
        name: 'The Celestine Kyoto',
        checkInDate: DateTime(2026, 10, 12),
        checkInTime: '15:00',
        checkOutDate: DateTime(2026, 10, 13),
        checkOutTime: '11:00',
      );

      const double totalWidth = 310.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StayHeaderBridgeWidget(
              stay: stay,
              width: totalWidth,
              spanDays: 1,
            ),
          ),
        ),
      );

      final night1Finder = find.text('Night 1');
      expect(night1Finder, findsOneWidget);

      final Offset night1Center = tester.getCenter(night1Finder);
      expect(night1Center.dx, closeTo(155.0, 5.0));
    });

    testWidgets('Renders empty stay slot with top spacing aligning with stay rectangles',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StayHeaderBridgeWidget(
              stay: null,
              width: 310.0,
            ),
          ),
        ),
      );

      expect(find.text('No lodging recorded for this night'), findsOneWidget);
    });

    testWidgets('Renders continued night numbering across stays (e.g. Night 3 and Night 4)',
        (WidgetTester tester) async {
      final stay = Stay(
        id: 'stay_test_cont',
        tripId: 'trip_test',
        type: StayType.hotel,
        name: 'The Celestine Kyoto',
        checkInDate: DateTime(2026, 10, 12),
        checkInTime: '15:00',
        checkOutDate: DateTime(2026, 10, 14),
        checkOutTime: '11:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StayHeaderBridgeWidget(
              stay: stay,
              width: 600.0,
              spanDays: 2,
              startNightNumber: 3,
            ),
          ),
        ),
      );

      expect(find.text('Night 3'), findsOneWidget);
      expect(find.text('Night 4'), findsOneWidget);
      expect(find.text('Night 1'), findsNothing);
      expect(find.text('Night 2'), findsNothing);
    });
  });
}
