import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/models/models.dart';
import 'package:trippy/state/trip_providers.dart';
import 'package:trippy/views/common/add_stay_sheet.dart';
import 'package:trippy/views/logistics/logistics_view.dart';
import 'package:trippy/views/logistics/widgets/flight_day_card_widget.dart';
import 'package:trippy/views/logistics/widgets/stay_header_bridge_widget.dart';

void main() {
  testWidgets('Arrival flight departing Nov 1 and arriving Nov 2 spans across Nov 1 to Day 2 center',
      (WidgetTester tester) async {
    final start = DateTime(2026, 11, 1);
    final end = DateTime(2026, 11, 5);

    final trip = Trip(
      id: 'trip_overnight_arr',
      title: 'Overnight Trip',
      destination: 'Tokyo, Japan',
      startDate: start,
      endDate: end,
      ownerId: 'user_current',
      inviteCode: 'TYO-26',
      defaultInviteRole: MemberRole.editor,
      members: {'user_current': MemberRole.owner},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final arrivalFlight = Flight(
      id: 'flt_arr_overnight',
      tripId: trip.id,
      airline: 'Delta Air Lines',
      flightNumber: 'DL0167',
      departureAirport: 'SEA',
      arrivalAirport: 'HND',
      departureTime: DateTime(2026, 11, 1, 11, 25),
      arrivalTime: DateTime(2026, 11, 2, 15, 5),
      isOvernight: true,
      isMainArrival: true,
      bookingRef: 'DL-9921',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeTripProvider.overrideWithValue(trip),
          activeTripFlightsProvider
              .overrideWith((ref) => Stream.value([arrivalFlight])),
          activeTripStaysProvider
              .overrideWith((ref) => Stream.value(<Stay>[])),
          activeTripActivitiesProvider
              .overrideWith((ref) => Stream.value(<Activity>[])),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: LogisticsView(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Day 1 and Day 2 dates are distinct
    final days = trip.daysList;
    expect(days[0], DateTime(2026, 11, 1));
    expect(days[1], DateTime(2026, 11, 2));

    // 2. Verify overnight flight appears horizontally as a StayHeaderBridgeWidget spanning Nov 1 to Day 2
    final overnightFlightBridgeFinder = find.byWidgetPredicate(
      (w) => w is StayHeaderBridgeWidget && w.stay?.id == 'stay_flight_flt_arr_overnight',
    );
    expect(overnightFlightBridgeFinder, findsOneWidget);

    final bridgeWidget =
        tester.widget<StayHeaderBridgeWidget>(overnightFlightBridgeFinder);
    expect(bridgeWidget.spanDays, 1);
    expect(find.text('Delta Air Lines DL0167'), findsWidgets);

    // Also verify flight card is rendered inside Day 1 column
    expect(find.byType(FlightDayCardWidget), findsOneWidget);

    // 3. Verify empty stay placeholder is clickable
    final emptyStayFinder = find.byWidgetPredicate(
      (w) => w is StayHeaderBridgeWidget && w.stay == null,
    );
    expect(emptyStayFinder, findsWidgets);

    // Tap on the empty stay placeholder to open AddStaySheet
    await tester.tap(emptyStayFinder.first);
    await tester.pumpAndSettle();

    expect(find.byType(AddStaySheet), findsOneWidget);
  });
}
