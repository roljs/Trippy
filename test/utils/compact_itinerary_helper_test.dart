import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/core/utils/city_color_helper.dart';
import 'package:trippy/core/utils/compact_itinerary_helper.dart';
import 'package:trippy/models/models.dart';

void main() {
  group('CompactItineraryHelper Tests with Thailandia 2026 Trip', () {
    late TripBundle bundle;

    setUp(() {
      final file = File('thailandia_2026_trip.json');
      final jsonString = file.readAsStringSync();
      bundle = TripBundle.fromJson(jsonString);
    });

    test('Parses 25 days and correctly identifies Spanish trip', () {
      expect(bundle.trip.daysList.length, 25);
      expect(CompactItineraryHelper.isSpanishTrip(bundle.trip), isTrue);
    });

    test('Generates exactly 25 compact summaries matching expected spreadsheet rows', () {
      final activitiesByDay = <DateTime, List<Activity>>{};
      for (final a in bundle.activities) {
        final d = DateTime(a.date.year, a.date.month, a.date.day);
        activitiesByDay.putIfAbsent(d, () => []).add(a);
      }

      final summaries = CompactItineraryHelper.generateSummaries(
        trip: bundle.trip,
        stays: bundle.stays,
        flights: bundle.flights,
        activitiesByDay: activitiesByDay,
      );

      expect(summaries.length, 25);

      // Row 1 (Nov 1): 1-Nov, Sunday, Fly, Flight, DL0167 note
      final day1 = summaries[0];
      expect(day1.formattedDate, '1-Nov');
      expect(day1.dayOfWeek, 'Sunday');
      expect(day1.placesToVisit, 'Fly');
      expect(day1.sleepAt, 'Flight');
      expect(day1.notes, contains('DL0167'));
      expect(day1.rowColor, CityColorHelper.flightPastel);

      // Row 2 (Nov 2): 2-Nov, Monday, Flight, Tokyo, Tokyo, Arrives at 3:05pm
      final day2 = summaries[1];
      expect(day2.formattedDate, '2-Nov');
      expect(day2.dayOfWeek, 'Monday');
      expect(day2.placesToVisit, 'Flight, Tokyo');
      expect(day2.sleepAt, 'Tokyo');
      expect(day2.notes, contains('Arrives at'));
      expect(day2.rowColor, CityColorHelper.getPastelColorForCity('Tokyo'));

      // Row 3 (Nov 3): 3-Nov, Tuesday, Tokyo, Nikko, Nikko
      final day3 = summaries[2];
      expect(day3.formattedDate, '3-Nov');
      expect(day3.dayOfWeek, 'Tuesday');
      expect(day3.placesToVisit, 'Tokyo, Nikko');
      expect(day3.sleepAt, 'Nikko');
      expect(day3.rowColor, CityColorHelper.getPastelColorForCity('Nikko'));

      // Row 4 (Nov 4): 4-Nov, Wednesday, Nikko, Tokyo, Tokyo
      final day4 = summaries[3];
      expect(day4.formattedDate, '4-Nov');
      expect(day4.dayOfWeek, 'Wednesday');
      expect(day4.placesToVisit, 'Nikko, Tokyo');
      expect(day4.sleepAt, 'Tokyo');
      expect(day4.rowColor, CityColorHelper.getPastelColorForCity('Tokyo'));

      // Row 5 (Nov 5): 5-Nov, Thursday, Tokyo, Tokyo
      final day5 = summaries[4];
      expect(day5.formattedDate, '5-Nov');
      expect(day5.dayOfWeek, 'Thursday');
      expect(day5.placesToVisit, 'Tokyo');
      expect(day5.sleepAt, 'Tokyo');
      expect(day5.rowColor, CityColorHelper.getPastelColorForCity('Tokyo'));

      // Row 6 (Nov 6): 6-Nov, Friday, Tokyo, Hanoi, Hanoi, Vietnam Airlines
      final day6 = summaries[5];
      expect(day6.formattedDate, '6-Nov');
      expect(day6.dayOfWeek, 'Friday');
      expect(day6.placesToVisit, 'Tokyo, Hanoi');
      expect(day6.sleepAt, 'Hanoi');
      expect(day6.notes, contains('Vietnam Airlines'));
      expect(day6.rowColor, CityColorHelper.getPastelColorForCity('Hanoi'));

      // Row 7 (Nov 7): 7-Nov, Saturday, Hanoi, HaLong Bay Cruise, Halong Bay Cruise
      final day7 = summaries[6];
      expect(day7.formattedDate, '7-Nov');
      expect(day7.dayOfWeek, 'Saturday');
      expect(day7.placesToVisit, contains('Hanoi'));
      expect(day7.sleepAt, 'Halong Bay Cruise');
      expect(day7.rowColor, CityColorHelper.getPastelColorForCity('Halong Bay Cruise'));

      // Row 8 (Nov 8): 8-Nov, Sunday, Halong Bay Cruise, Halong Bay Cruise
      final day8 = summaries[7];
      expect(day8.formattedDate, '8-Nov');
      expect(day8.dayOfWeek, 'Sunday');
      expect(day8.sleepAt, 'Halong Bay Cruise');
      expect(day8.rowColor, CityColorHelper.getPastelColorForCity('Halong Bay Cruise'));

      // Row 10 (Nov 10): 10-Nov, Tuesday, Hanoi, Hanoi
      final day10 = summaries[9];
      expect(day10.formattedDate, '10-Nov');
      expect(day10.dayOfWeek, 'Tuesday');
      expect(day10.sleepAt, 'Hanoi');
      expect(day10.rowColor, CityColorHelper.getPastelColorForCity('Hanoi'));

      // Row 11 (Nov 11): 11-Nov, Wednesday, Hanoi, Siem Reap, Siem Reap
      final day11 = summaries[10];
      expect(day11.formattedDate, '11-Nov');
      expect(day11.dayOfWeek, 'Wednesday');
      expect(day11.placesToVisit, 'Hanoi, Siem Reap');
      expect(day11.sleepAt, 'Siem Reap');
      expect(day11.notes, contains('Vietnam Airlines'));
      expect(day11.rowColor, CityColorHelper.getPastelColorForCity('Siem Reap'));

      // Row 14 (Nov 14): 14-Nov, Saturday, Siem Reap, Bangkok, Bangkok
      final day14 = summaries[13];
      expect(day14.formattedDate, '14-Nov');
      expect(day14.dayOfWeek, 'Saturday');
      expect(day14.placesToVisit, 'Siem Reap, Bangkok');
      expect(day14.sleepAt, 'Bangkok');
      expect(day14.notes, contains('Bangkok Airways'));
      expect(day14.rowColor, CityColorHelper.getPastelColorForCity('Bangkok'));

      // Row 19 (Nov 19): 19-Nov, Thursday, Bangkok, Singapore, Singapore
      final day19 = summaries[18];
      expect(day19.formattedDate, '19-Nov');
      expect(day19.dayOfWeek, 'Thursday');
      expect(day19.placesToVisit, 'Bangkok, Singapore');
      expect(day19.sleepAt, 'Singapore');
      expect(day19.notes, contains('Singapore Airlines'));
      expect(day19.rowColor, CityColorHelper.getPastelColorForCity('Singapore'));

      // Row 21 (Nov 21): 21-Nov, Saturday, Singapore, Seoul, Seoul
      final day21 = summaries[20];
      expect(day21.formattedDate, '21-Nov');
      expect(day21.dayOfWeek, 'Saturday');
      expect(day21.placesToVisit, 'Singapore, Seoul');
      expect(day21.sleepAt, 'Seoul');
      expect(day21.notes, contains('Singapore Airlines'));
      expect(day21.rowColor, CityColorHelper.getPastelColorForCity('Seoul'));

      // Row 25 (Nov 25): 25-Nov, Wednesday, Seoul, Flight, Seattle, Seattle
      final day25 = summaries[24];
      expect(day25.formattedDate, '25-Nov');
      expect(day25.dayOfWeek, 'Wednesday');
      expect(day25.placesToVisit, 'Seoul, Flight, Seattle');
      expect(day25.sleepAt, 'Seattle');
      expect(day25.notes, contains('Delta Air Lines'));
      expect(day25.rowColor, CityColorHelper.getPastelColorForCity('Seattle'));
    });

    test('Sleep At cell includes Stay references for hover card on hotel nights', () {
      final activitiesByDay = <DateTime, List<Activity>>{};
      final summaries = CompactItineraryHelper.generateSummaries(
        trip: bundle.trip,
        stays: bundle.stays,
        flights: bundle.flights,
        activitiesByDay: activitiesByDay,
      );

      // Night 2 has APA Hotel
      final day2 = summaries[1];
      expect(day2.stayTonight, isNotNull);
      expect(day2.stayTonight!.name, 'APA Hotel Asakusa Tawaramachi Ekimae');
      expect(day2.stayTonight!.address, contains('Tokyo'));
      expect(day2.stayTonight!.confirmationCode, '20260821060007');

      // Night 3 has Nikko Ryokan
      final day3 = summaries[2];
      expect(day3.stayTonight, isNotNull);
      expect(day3.stayTonight!.name, anyOf(contains('Nikko'), contains('Koduchi')));

      // Night 7 has Cruise
      final day7 = summaries[6];
      expect(day7.stayTonight, isNotNull);
      expect(day7.stayTonight!.name, contains('Luxury Cruise'));

      // Night 11 has Siem Reap Stay
      final day11 = summaries[10];
      expect(day11.stayTonight, isNotNull);
      expect(day11.stayTonight!.name, anyOf(contains('Siem Reap'), contains('Templation')));

      // Night 14 has Bangkok Stay
      final day14 = summaries[13];
      expect(day14.stayTonight, isNotNull);
      expect(day14.stayTonight!.name, anyOf(contains('Bangkok'), contains('Avani')));

      // Night 19 has Singapore Stay
      final day19 = summaries[18];
      expect(day19.stayTonight, isNotNull);
      expect(day19.stayTonight!.name, anyOf(contains('Singapore'), contains('ParkRoyal')));

      // Night 21 has Seoul Myeongdong Hotel
      final day21 = summaries[20];
      expect(day21.stayTonight, isNotNull);
      expect(day21.stayTonight!.name, 'Seoul Myeongdong Hotel');
    });
  });

  group('CompactItineraryHelper Tests with English Seeded Trips', () {
    late Trip japanTrip;
    late List<Stay> japanStays;
    late List<Flight> japanFlights;
    late Map<DateTime, List<Activity>> japanActivitiesByDay;

    setUp(() {
      final now = DateTime.now();
      final day1 = DateTime(now.year, now.month, now.day + 15);
      final day3 = day1.add(const Duration(days: 2));
      final day5 = day1.add(const Duration(days: 4));

      japanTrip = Trip(
        id: 'trip_japan_2026',
        title: 'Japan Odyssey: Tokyo & Kyoto',
        destination: 'Tokyo & Kyoto, Japan',
        startDate: day1,
        endDate: day5,
        ownerId: 'user_current',
        inviteCode: 'TYO-8821',
        defaultInviteRole: MemberRole.editor,
        members: const {'user_current': MemberRole.owner},
        createdAt: now,
        updatedAt: now,
      );

      japanStays = [
        Stay(
          id: 'stay_01',
          tripId: japanTrip.id,
          type: StayType.hotel,
          name: 'Grand Hyatt Tokyo',
          address: '6-10-3 Roppongi, Minato City, Tokyo',
          checkInDate: day1,
          checkOutDate: day3,
        ),
        Stay(
          id: 'stay_02',
          tripId: japanTrip.id,
          type: StayType.hotel,
          name: 'The Celestine Kyoto Gion',
          address: '572 Komatsucho, Higashiyama Ward, Kyoto',
          checkInDate: day3,
          checkOutDate: day5,
        ),
      ];

      japanFlights = [
        Flight(
          id: 'flt_01',
          tripId: japanTrip.id,
          airline: 'ANA',
          flightNumber: 'NH107',
          departureAirport: 'SFO (San Francisco)',
          arrivalAirport: 'HND (Tokyo)',
          departureTime: day1.add(const Duration(hours: 11)),
          arrivalTime: day1.add(const Duration(hours: 15)),
          isMainArrival: true,
        ),
      ];

      japanActivitiesByDay = {
        day1: [
          Activity(
            id: 'a1',
            tripId: japanTrip.id,
            date: day1,
            startTime: '09:30',
            title: 'Arrival in Tokyo',
            category: ActivityCategory.transport,
          ),
        ],
        day3: [
          Activity(
            id: 'a3',
            tripId: japanTrip.id,
            date: day3,
            startTime: '10:00',
            title: 'Shinkansen Bullet Train to Kyoto',
            category: ActivityCategory.transport,
            location: 'Tokyo Station -> Kyoto Station',
            notes: 'Reserved Car 5, Seats 8D & 8E (Mount Fuji side!)',
          ),
        ],
      };
    });

    test('Generates English day of week and clean summaries for Japan trip', () {
      expect(CompactItineraryHelper.isSpanishTrip(japanTrip), isFalse);

      final summaries = CompactItineraryHelper.generateSummaries(
        trip: japanTrip,
        stays: japanStays,
        flights: japanFlights,
        activitiesByDay: japanActivitiesByDay,
      );

      expect(summaries.length, 5);
      expect(summaries[0].dayOfWeek, anyOf('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'));
      expect(summaries[0].sleepAt, 'Tokyo');
      expect(summaries[2].placesToVisit, contains('Tokyo'));
      expect(summaries[2].sleepAt, 'Kyoto');
      expect(summaries[2].notes, contains('Mount Fuji'));
    });
  });
}
