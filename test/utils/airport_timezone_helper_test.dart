import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/core/utils/airport_timezone_helper.dart';

void main() {
  group('AirportTimezoneHelper', () {
    test('Calculates SEA to HND flight duration considering timezone changes', () {
      // 2026-11-01 11:25 at SEA (PST, UTC-8) to 2026-11-02 15:05 at HND (JST, UTC+9)
      final dep = DateTime(2026, 11, 1, 11, 25);
      final arr = DateTime(2026, 11, 2, 15, 5);

      final duration = AirportTimezoneHelper.calculateDuration(
        departureTime: dep,
        departureAirport: 'SEA (Seattle)',
        arrivalTime: arr,
        arrivalAirport: 'HND (Tokyo Haneda)',
      );

      // Duration should be exactly 10 hours and 40 minutes (not naive 27h 40m)
      expect(duration.inHours, 10);
      expect(duration.inMinutes.remainder(60), 40);
      expect(duration.inMinutes, 640);
    });

    test('Calculates ICN to SEA flight duration across International Date Line', () {
      // 2026-11-25 18:45 at ICN (KST, UTC+9) to 2026-11-25 11:51 at SEA (PST, UTC-8)
      final dep = DateTime(2026, 11, 25, 18, 45);
      final arr = DateTime(2026, 11, 25, 11, 51);

      final duration = AirportTimezoneHelper.calculateDuration(
        departureTime: dep,
        departureAirport: 'ICN (Seoul Incheon)',
        arrivalTime: arr,
        arrivalAirport: 'SEA (Seattle)',
      );

      // In UTC: Dep is 09:45 Nov 25, Arr is 19:51 Nov 25 -> 10h 6m
      expect(duration.inHours, 10);
      expect(duration.inMinutes.remainder(60), 6);
    });

    test('Calculates HND to HAN flight duration', () {
      // 2026-11-06 16:35 at HND (UTC+9) to 2026-11-06 20:50 at HAN (UTC+7)
      final dep = DateTime(2026, 11, 6, 16, 35);
      final arr = DateTime(2026, 11, 6, 20, 50);

      final duration = AirportTimezoneHelper.calculateDuration(
        departureTime: dep,
        departureAirport: 'HND (Tokyo Haneda)',
        arrivalTime: arr,
        arrivalAirport: 'HAN (Hanoi Noi Bai)',
      );

      // UTC Dep 07:35, UTC Arr 13:50 -> 6h 15m
      expect(duration.inHours, 6);
      expect(duration.inMinutes.remainder(60), 15);
    });

    test('Calculates BKK to SIN flight duration', () {
      // 2026-11-19 12:00 at BKK (UTC+7) to 2026-11-19 15:35 at SIN (UTC+8)
      final dep = DateTime(2026, 11, 19, 12, 0);
      final arr = DateTime(2026, 11, 19, 15, 35);

      final duration = AirportTimezoneHelper.calculateDuration(
        departureTime: dep,
        departureAirport: 'BKK (Bangkok Suvarnabhumi)',
        arrivalTime: arr,
        arrivalAirport: 'SIN (Singapore Changi)',
      );

      // UTC Dep 05:00, UTC Arr 07:35 -> 2h 35m
      expect(duration.inHours, 2);
      expect(duration.inMinutes.remainder(60), 35);
    });

    test('Extracts IATA codes from various string formats', () {
      expect(AirportTimezoneHelper.extractIataCode('SEA'), 'SEA');
      expect(AirportTimezoneHelper.extractIataCode('SEA (Seattle)'), 'SEA');
      expect(AirportTimezoneHelper.extractIataCode('Seattle (SEA)'), 'SEA');
      expect(AirportTimezoneHelper.extractIataCode('HND (Tokyo Haneda)'), 'HND');
      expect(AirportTimezoneHelper.extractIataCode('Tokyo'), 'HND');
    });
  });
}
