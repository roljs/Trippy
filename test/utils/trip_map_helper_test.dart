import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/core/utils/trip_map_helper.dart';
import 'package:trippy/models/models.dart';

void main() {
  group('TripMapHelper Tests with Thailandia 2026 Trip', () {
    late TripBundle thaiBundle;

    setUp(() {
      final file = File('thailandia_2026_trip.json');
      final jsonString = file.readAsStringSync();
      thaiBundle = TripBundle.fromJson(jsonString);
    });

    test('extractRoute builds chronological city nodes with 1-based sequence numbers', () {
      final activitiesByDay = <DateTime, List<Activity>>{};
      for (final a in thaiBundle.activities) {
        final d = DateTime(a.date.year, a.date.month, a.date.day);
        activitiesByDay.putIfAbsent(d, () => []).add(a);
      }

      final route = TripMapHelper.extractRoute(
        trip: thaiBundle.trip,
        flights: thaiBundle.flights,
        stays: thaiBundle.stays,
        activitiesByDay: activitiesByDay,
      );

      expect(route.cities.isNotEmpty, isTrue);
      // City sequence numbers must start at 1 and increment chronologically
      for (int i = 0; i < route.cities.length; i++) {
        expect(route.cities[i].sequenceNumber, equals(i + 1));
      }

      final cityNames = route.cities.map((c) => c.cityName).toList();
      // Should include origin Seattle and key destinations
      expect(cityNames, contains('Seattle'));
      expect(cityNames, contains('Tokyo'));
      expect(cityNames, contains('Hanoi'));
      expect(cityNames, contains('Bangkok'));

      // Seattle should be first (origin)
      expect(route.cities.first.cityName, equals('Seattle'));
      expect(route.cities.first.sequenceNumber, equals(1));
    });

    test('extractRoute creates connection legs with flight monikers', () {
      final activitiesByDay = <DateTime, List<Activity>>{};
      for (final a in thaiBundle.activities) {
        final d = DateTime(a.date.year, a.date.month, a.date.day);
        activitiesByDay.putIfAbsent(d, () => []).add(a);
      }

      final route = TripMapHelper.extractRoute(
        trip: thaiBundle.trip,
        flights: thaiBundle.flights,
        stays: thaiBundle.stays,
        activitiesByDay: activitiesByDay,
      );

      expect(route.legs.isNotEmpty, isTrue);

      final flightMonikers = route.legs
          .where((l) => l.flight != null)
          .map((l) => l.moniker)
          .toList();

      // Flights in Thailandia trip include DL0167, VN0385, PG0906, SQ0709, SQ0606, DL0198
      expect(flightMonikers.any((m) => m.contains('DL') || m.contains('167')), isTrue);
      expect(flightMonikers.any((m) => m.contains('VN') || m.contains('PG') || m.contains('SQ')), isTrue);
    });

    test('extractRoute accurately identifies Pacific crossing for trans-Pacific routes', () {
      final activitiesByDay = <DateTime, List<Activity>>{};
      for (final a in thaiBundle.activities) {
        final d = DateTime(a.date.year, a.date.month, a.date.day);
        activitiesByDay.putIfAbsent(d, () => []).add(a);
      }

      final route = TripMapHelper.extractRoute(
        trip: thaiBundle.trip,
        flights: thaiBundle.flights,
        stays: thaiBundle.stays,
        activitiesByDay: activitiesByDay,
      );

      // Seattle (lng ~ -122) to Asia (lng ~ 100-140) crosses the Pacific Ocean
      expect(route.crossesPacific, isTrue);
    });

    test('resolveCoordinates resolves known international airports and cities', () {
      final tokyo = TripMapHelper.resolveCoordinates('Tokyo');
      expect(tokyo.lat, closeTo(35.6762, 0.5));
      expect(tokyo.lng, closeTo(139.6503, 0.5));

      final seattle = TripMapHelper.resolveCoordinates('Seattle');
      expect(seattle.lat, closeTo(47.6062, 0.5));
      expect(seattle.lng, closeTo(-122.3321, 0.5));

      final bangkok = TripMapHelper.resolveCoordinates('Bangkok');
      expect(bangkok.lat, closeTo(13.7563, 0.5));
      expect(bangkok.lng, closeTo(100.5018, 0.5));
    });

    test('extractRoute generates callout offsets for multi-visit cities to avoid overlaps', () {
      final activitiesByDay = <DateTime, List<Activity>>{};
      for (final a in thaiBundle.activities) {
        final d = DateTime(a.date.year, a.date.month, a.date.day);
        activitiesByDay.putIfAbsent(d, () => []).add(a);
      }

      final route = TripMapHelper.extractRoute(
        trip: thaiBundle.trip,
        flights: thaiBundle.flights,
        stays: thaiBundle.stays,
        activitiesByDay: activitiesByDay,
      );

      // Tokyo has 2 visits (Seq 2 and Seq 4)
      final tokyoStops = route.cities.where((c) => c.cityName == 'Tokyo').toList();
      expect(tokyoStops.length, equals(2));
      expect(tokyoStops[0].totalVisitsToThisCity, equals(2));
      expect(tokyoStops[1].totalVisitsToThisCity, equals(2));
      expect(tokyoStops[0].calloutOffset, isNot(equals(Offset.zero)));
      expect(tokyoStops[1].calloutOffset, isNot(equals(Offset.zero)));
      expect(tokyoStops[0].calloutOffset, isNot(equals(tokyoStops[1].calloutOffset)));

      // Hanoi has 2 visits (Seq 5 and Seq 8)
      final hanoiStops = route.cities.where((c) => c.cityName == 'Hanoi').toList();
      expect(hanoiStops.length, equals(2));
      expect(hanoiStops[0].calloutOffset, isNot(equals(hanoiStops[1].calloutOffset)));

      // Bangkok has 2 visits (Seq 10 and Seq 12)
      final bkkStops = route.cities.where((c) => c.cityName == 'Bangkok').toList();
      expect(bkkStops.length, equals(2));
      expect(bkkStops[0].calloutOffset, isNot(equals(bkkStops[1].calloutOffset)));

      // Seattle has 2 visits (Seq 1 departure and Seq 15 return)
      final seaStops = route.cities.where((c) => c.cityName == 'Seattle').toList();
      expect(seaStops.length, equals(2));
      expect(seaStops[0].calloutOffset, isNot(equals(seaStops[1].calloutOffset)));
    });

    test('extractRoute correctly recognizes flights without mistaking them as transfers', () {
      final activitiesByDay = <DateTime, List<Activity>>{};
      for (final a in thaiBundle.activities) {
        final d = DateTime(a.date.year, a.date.month, a.date.day);
        activitiesByDay.putIfAbsent(d, () => []).add(a);
      }

      final route = TripMapHelper.extractRoute(
        trip: thaiBundle.trip,
        flights: thaiBundle.flights,
        stays: thaiBundle.stays,
        activitiesByDay: activitiesByDay,
      );

      // Verify Bangkok -> Singapore is flight SQ707, not a transfer
      final bkkToSin = route.legs.firstWhere(
        (l) => l.fromCity.cityName == 'Bangkok' && l.toCity.cityName == 'Singapore',
      );
      expect(bkkToSin.isFlight, isTrue);
      expect(bkkToSin.moniker, contains('707'));

      // Verify Singapore -> Seoul is flight SQ606, not a transfer
      final sinToSel = route.legs.firstWhere(
        (l) => l.fromCity.cityName == 'Singapore' && l.toCity.cityName == 'Seoul',
      );
      expect(sinToSel.isFlight, isTrue);
      expect(sinToSel.moniker, contains('606'));

      // Verify Seoul -> Seattle is flight DL0198
      final selToSea = route.legs.firstWhere(
        (l) => l.fromCity.cityName == 'Seoul' && l.toCity.cityName == 'Seattle',
      );
      expect(selToSea.isFlight, isTrue);
      expect(selToSea.moniker, contains('198'));
    });
  });
}
