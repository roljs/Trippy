import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/main.dart';
import 'package:trippy/views/day_planner/day_planner_view.dart';
import 'package:trippy/views/logistics/widgets/day_column_widget.dart';
import 'package:trippy/views/logistics/widgets/stay_header_bridge_widget.dart';
import 'package:trippy/views/logistics/widgets/trip_endcap_stay_bridge_widget.dart';

void main() {
  testWidgets('Trippy app loads and renders navigation scaffold with Day Planner default', (WidgetTester tester) async {
    // Increase test surface size so horizontal and vertical widgets layout cleanly
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: TrippyApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify top bar and bottom nav exist
    expect(find.text('Japan Odyssey: Tokyo & Kyoto'), findsOneWidget);
    expect(find.text('Day Planner'), findsOneWidget);
    expect(find.text('Itinerary'), findsOneWidget);
    expect(find.text('Flights'), findsOneWidget);
    expect(find.text('Stays'), findsOneWidget);
    expect(find.text('Activities'), findsOneWidget);
    expect(find.text('Trips'), findsOneWidget);

    // Verify DayPlannerView is rendered as the first and default view
    expect(find.byType(DayPlannerView), findsOneWidget);

    // Switch to Itinerary tab
    await tester.tap(find.text('Itinerary'));
    await tester.pumpAndSettle();

    // Verify day columns and stay bridges render
    expect(find.byType(DayColumnWidget), findsWidgets);
    expect(find.byType(StayHeaderBridgeWidget), findsWidgets);
    expect(find.byType(TripEndcapStayBridgeWidget), findsNWidgets(2));
    expect(find.text('START'), findsOneWidget);
    expect(find.text('FINISH'), findsOneWidget);

    // Verify hotel stay bridge text and night segmentation
    expect(find.text('Grand Hyatt Tokyo'), findsOneWidget);
    expect(find.text('2 nights'), findsWidgets);
    expect(find.text('Night 1 • Tokyo'), findsWidgets);
    expect(find.text('Night 2 • Tokyo'), findsWidgets);

    // Verify day locations render in day headers
    expect(find.text('Japan'), findsWidgets);
    expect(find.text('Tokyo'), findsWidgets);

    // Tap on Flights tab
    await tester.tap(find.text('Flights'));
    await tester.pumpAndSettle();

    expect(find.text('All Nippon Airways'), findsOneWidget);
    expect(find.text('Japan Airlines'), findsOneWidget);

    // Tap on Stays tab
    await tester.tap(find.text('Stays'));
    await tester.pumpAndSettle();

    expect(find.text('Grand Hyatt Tokyo'), findsOneWidget);
    expect(find.text('The Celestine Kyoto Gion'), findsOneWidget);
    expect(find.text('2 NIGHTS'), findsWidgets);

    // Tap on Activities tab
    await tester.tap(find.text('Activities'));
    await tester.pumpAndSettle();

    expect(find.text('Tsukiji Outer Market Food Crawl'), findsOneWidget);
    expect(find.text('Senso-ji Temple & Asakusa Walking Tour'), findsOneWidget);

    // Tap on Trips tab
    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();

    expect(find.text('My Trips'), findsOneWidget);
    expect(find.text('Code: TYO-8821'), findsOneWidget);
    expect(find.text('Code: ITA-4029'), findsOneWidget); // Trip 2
  });
}
