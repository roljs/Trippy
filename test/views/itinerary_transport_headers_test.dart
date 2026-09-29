import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/views/logistics/widgets/stay_header_bridge_widget.dart';
import 'package:trippy/views/logistics/widgets/transport_header_bridge_widget.dart';

void main() {
  group('TransportHeaderBridgeWidget Tests', () {
    testWidgets('Renders Arrival flight header with badge and details',
        (WidgetTester tester) async {
      final flight = Flight(
        id: 'flt_test_01',
        tripId: 'trip_test',
        airline: 'All Nippon Airways',
        flightNumber: 'NH203',
        departureAirport: 'SFO',
        arrivalAirport: 'HND',
        departureTime: DateTime(2026, 10, 10, 12, 0),
        arrivalTime: DateTime(2026, 10, 11, 9, 30),
        bookingRef: 'ANA-9921',
      );

      final data = TransportHeaderData.fromFlight(
          flight, TransportHeaderMode.arrival);

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransportHeaderBridgeWidget(
              mode: TransportHeaderMode.arrival,
              data: data,
              width: 290,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('All Nippon Airways NH203'), findsOneWidget);
      expect(find.text('ARRIVAL'), findsOneWidget);
      expect(find.text('#ANA-9921'), findsOneWidget);
      expect(find.byIcon(Icons.flight_takeoff_rounded), findsOneWidget);

      await tester.tap(find.byType(TransportHeaderBridgeWidget));
      expect(tapped, isTrue);
    });

    testWidgets('Renders Departure train header with badge and details',
        (WidgetTester tester) async {
      final activity = Activity(
        id: 'act_test_train',
        tripId: 'trip_test',
        date: DateTime(2026, 10, 20),
        startTime: '17:30',
        title: 'Shinkansen Bullet Train to Tokyo',
        category: ActivityCategory.transport,
        location: 'Kyoto Station',
        confirmationRef: 'SHINK-10',
      );

      final data = TransportHeaderData.fromActivity(
          activity, TransportHeaderMode.departure);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransportHeaderBridgeWidget(
              mode: TransportHeaderMode.departure,
              data: data,
              width: 290,
            ),
          ),
        ),
      );

      expect(find.text('Shinkansen Bullet Train to Tokyo'), findsOneWidget);
      expect(find.text('DEPARTURE'), findsOneWidget);
      expect(find.text('#SHINK-10'), findsOneWidget);
      expect(find.byIcon(Icons.train_rounded), findsOneWidget);
    });

    testWidgets('Renders placeholder headers gracefully',
        (WidgetTester tester) async {
      final placeholderData = TransportHeaderData.placeholder(
        mode: TransportHeaderMode.arrival,
        destination: 'Kyoto, Japan',
        type: TransportType.car,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransportHeaderBridgeWidget(
              mode: TransportHeaderMode.arrival,
              data: placeholderData,
              width: 290,
            ),
          ),
        ),
      );

      expect(find.text('Arrival: Car / Drive to Kyoto, Japan'), findsOneWidget);
      expect(find.text('ARRIVAL'), findsOneWidget);
      expect(find.byIcon(Icons.directions_car_rounded), findsOneWidget);
    });
  });

  group('StayHeaderBridgeWidget Night Segmentation Tests', () {
    testWidgets('Renders multi-night stay with night subelements and dividers',
        (WidgetTester tester) async {
      final stay = Stay(
        id: 'stay_multi',
        tripId: 'trip_01',
        type: StayType.hotel,
        name: 'The Celestine Kyoto Gion',
        checkInDate: DateTime(2026, 10, 10),
        checkOutDate: DateTime(2026, 10, 13), // 3 nights
        confirmationCode: 'CEL-99',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StayHeaderBridgeWidget(
              stay: stay,
              width: 930.0, // 3 strides * 310
              spanDays: 3,
            ),
          ),
        ),
      );

      expect(find.text('The Celestine Kyoto Gion'), findsOneWidget);
      expect(find.text('3 nights'), findsOneWidget);
      expect(find.text('HOTEL • 3N'), findsOneWidget);

      // Verify night segmentation badges/labels
      expect(find.text('Night 1'), findsOneWidget);
      expect(find.text('Night 2'), findsOneWidget);
      expect(find.text('Night 3'), findsOneWidget);
    });

    testWidgets('Renders empty stay placeholder with clickable onTap callback',
        (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StayHeaderBridgeWidget(
              stay: null,
              width: 310.0,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('No lodging recorded for this night'), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);

      await tester.tap(find.text('No lodging recorded for this night'));
      expect(tapped, isTrue);
    });
  });
}
