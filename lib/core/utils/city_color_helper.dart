import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../views/logistics/widgets/stay_header_bridge_widget.dart';

/// Helper to extract canonical city names and consistently map colors
/// for stays, flights, and itinerary rows.
class CityColorHelper {
  // Flight palette for overnight flights or flight stays
  static const StayGradientPalette flightPalette = overnightFlightPalette;

  // Flight row pastel for compact view
  static const Color flightPastel = Color(0xFFE0F2FE); // Soft sky blue

  // Default neutral color
  static const Color neutralPastel = Color(0xFFFFFFFF);

  // Curated stay gradient palettes for cities (distinct from flight blue)
  static const List<StayGradientPalette> _cityStayPalettes = [
    // 0. Imperial Violet / Purple
    StayGradientPalette(
      gradient: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
      shadow: Color(0xFF7C3AED),
    ),
    // 1. Emerald Green
    StayGradientPalette(
      gradient: [Color(0xFF065F46), Color(0xFF059669)],
      shadow: Color(0xFF059669),
    ),
    // 2. Sunset Crimson / Rose
    StayGradientPalette(
      gradient: [Color(0xFF9F1239), Color(0xFFE11D48)],
      shadow: Color(0xFFE11D48),
    ),
    // 3. Deep Teal
    StayGradientPalette(
      gradient: [Color(0xFF0F766E), Color(0xFF0D9488)],
      shadow: Color(0xFF0D9488),
    ),
    // 4. Amber Ochre
    StayGradientPalette(
      gradient: [Color(0xFF9A3412), Color(0xFFEA580C)],
      shadow: Color(0xFFEA580C),
    ),
    // 5. Indigo / Royal Blue
    StayGradientPalette(
      gradient: [Color(0xFF312E81), Color(0xFF4F46E5)],
      shadow: Color(0xFF4F46E5),
    ),
    // 6. Warm Magenta / Plum
    StayGradientPalette(
      gradient: [Color(0xFF831843), Color(0xFFBE185D)],
      shadow: Color(0xFFBE185D),
    ),
    // 7. Forest Olive Green
    StayGradientPalette(
      gradient: [Color(0xFF365314), Color(0xFF4D7C0F)],
      shadow: Color(0xFF4D7C0F),
    ),
  ];

  // Curated soft pastel colors for compact view rows
  static const Map<String, Color> _wellKnownCityPastels = {
    'tokyo': Color(0xFFE2F0D9), // Soft pastel green
    'nikko': Color(0xFFD4EDDA), // Soft sage green
    'hanoi': Color(0xFFDDEBF7), // Soft sky blue
    'ha long bay': Color(0xFFD0F0FD), // Soft cyan
    'halong bay': Color(0xFFD0F0FD),
    'halong bay cruise': Color(0xFFD0F0FD),
    'ninh binh': Color(0xFFC8E3F8), // Soft powder blue
    'ninh bin': Color(0xFFC8E3F8),
    'siem reap': Color(0xFFFCE4D6), // Soft peach
    'angkor': Color(0xFFFCE4D6),
    'bangkok': Color(0xFFE8D7F1), // Soft lavender
    'ayutthaya': Color(0xFFFBE5D6), // Soft warm peach
    'singapore': Color(0xFFD9E1F2), // Soft periwinkle
    'singapur': Color(0xFFD9E1F2),
    'seoul': Color(0xFFEDEDED), // Soft cool gray
    'corea': Color(0xFFEDEDED),
    'korea': Color(0xFFEDEDED),
    'seattle': Color(0xFFFEEFC3), // Soft light amber
  };

  static final List<Color> _rotatingPastelColors = [
    const Color(0xFFE2F0D9),
    const Color(0xFFDDEBF7),
    const Color(0xFFFCE4D6),
    const Color(0xFFE8D7F1),
    const Color(0xFFD9E1F2),
    const Color(0xFFEDEDED),
    const Color(0xFFFFF2CC),
    const Color(0xFFD0F0FD),
  ];

  /// Extracts the canonical city name for a given [Stay].
  /// Returns null if the stay is an overnight flight.
  static String? extractCityForStay(Stay stay) {
    if (stay.type == StayType.overnightFlight || stay.overnightFlight != null) {
      return null;
    }

    final addr = stay.address?.toLowerCase() ?? '';
    final name = stay.name.toLowerCase();

    // Check specific known cities
    if (addr.contains('tokyo') || name.contains('tokyo')) return 'Tokyo';
    if (addr.contains('nikko') || name.contains('nikko')) return 'Nikko';
    if (addr.contains('halong') || addr.contains('ha long') || name.contains('halong') || name.contains('ha long')) {
      return 'Ha Long Bay';
    }
    if (addr.contains('hanoi') || name.contains('hanoi')) return 'Hanoi';
    if (addr.contains('ninh bin') || name.contains('ninh bin') || addr.contains('xuan son') || name.contains('xuan son')) return 'Ninh Binh';
    if (addr.contains('ayutthaya') || name.contains('ayutthaya')) return 'Ayutthaya';
    if (addr.contains('siem reap') || addr.contains('angkor') || name.contains('siem reap') || name.contains('angkor')) {
      return 'Siem Reap';
    }
    if (addr.contains('bangkok') || name.contains('bangkok')) return 'Bangkok';
    if (addr.contains('singapore') || addr.contains('singapur') || name.contains('singapore') || name.contains('singapur')) {
      return 'Singapore';
    }
    if (addr.contains('seoul') || addr.contains('corea') || addr.contains('korea') || name.contains('seoul')) {
      return 'Seoul';
    }
    if (addr.contains('seattle') || name.contains('seattle')) return 'Seattle';
    if (addr.contains('kyoto') || name.contains('kyoto')) return 'Kyoto';
    if (addr.contains('osaka') || name.contains('osaka')) return 'Osaka';

    // Fallback: parse address segments (e.g. "Hoan Kiem, Hanoi, Vietnam")
    if (stay.address != null && stay.address!.isNotEmpty) {
      final parts = stay.address!.split(',');
      if (parts.length >= 2) {
        return parts[parts.length - 2].trim();
      }
      return parts.first.trim();
    }

    return stay.name.trim();
  }

  /// Returns the deterministic [StayGradientPalette] for a given city.
  /// Stays in the SAME city will ALWAYS get the exact same palette.
  /// Flights get [overnightFlightPalette].
  static StayGradientPalette getStayPalette({
    required Stay? stay,
    List<Stay>? allStaysInTrip,
  }) {
    if (stay == null) {
      return _cityStayPalettes[0];
    }

    if (stay.type == StayType.overnightFlight || stay.overnightFlight != null) {
      return flightPalette;
    }

    final city = extractCityForStay(stay);
    if (city == null || city.isEmpty) {
      return _cityStayPalettes[0];
    }

    return getPaletteForCity(city, allStaysInTrip: allStaysInTrip);
  }

  /// Returns the deterministic [StayGradientPalette] for a city name.
  static StayGradientPalette getPaletteForCity(
    String city, {
    List<Stay>? allStaysInTrip,
  }) {
    final lower = city.toLowerCase();

    // If allStaysInTrip is provided, assign indexes based on order of appearance of cities
    if (allStaysInTrip != null && allStaysInTrip.isNotEmpty) {
      final seenCities = <String>[];
      for (final s in allStaysInTrip) {
        final c = extractCityForStay(s);
        if (c != null && c.isNotEmpty) {
          final cLower = c.toLowerCase();
          if (!seenCities.contains(cLower)) {
            seenCities.add(cLower);
          }
        }
      }
      final cityIdx = seenCities.indexOf(lower);
      if (cityIdx >= 0) {
        return _cityStayPalettes[cityIdx % _cityStayPalettes.length];
      }
    }

    // Deterministic hash assignment
    final hash = lower.codeUnits.fold<int>(0, (sum, cu) => sum + cu);
    return _cityStayPalettes[hash % _cityStayPalettes.length];
  }

  /// Returns the soft pastel color for a compact itinerary row based on city name.
  static Color getPastelColorForCity(String city) {
    final lower = city.toLowerCase().trim();
    if (_wellKnownCityPastels.containsKey(lower)) {
      return _wellKnownCityPastels[lower]!;
    }
    // Partial matches
    for (final entry in _wellKnownCityPastels.entries) {
      if (lower.contains(entry.key) || entry.key.contains(lower)) {
        return entry.value;
      }
    }
    final hash = lower.codeUnits.fold<int>(0, (sum, cu) => sum + cu);
    return _rotatingPastelColors[hash % _rotatingPastelColors.length];
  }

  /// Extracts the chronologically FIRST city from a day summary.
  /// If the day contains multiple places (e.g. "Tokyo, Nikko" or "Siem Reap, Bangkok"),
  /// returns the first city visited.
  /// If the day is an overnight flight transit (e.g. "Volar" or "Avión"), returns null.
  static String? extractFirstCityForDay({
    required String placesToVisit,
    required String sleepAt,
    required String? previousSleepAt,
    required List<Flight> dayFlights,
    required List<Activity> dayActivities,
  }) {
    // Check if purely a flight day (e.g. Day 1 "Volar", "Avión")
    final pLower = placesToVisit.toLowerCase().trim();
    if (pLower == 'volar' || pLower == 'fly' || pLower == 'flight') {
      return null;
    }

    // Split places by comma
    final rawPlaces = placesToVisit.split(',').map((s) => s.trim()).toList();
    final nonFlightPlaces = rawPlaces.where((p) {
      final l = p.toLowerCase();
      return p.isNotEmpty &&
          l != 'volar' &&
          l != 'fly' &&
          l != 'avion' &&
          l != 'avión' &&
          l != 'flight';
    }).toList();

    if (nonFlightPlaces.isNotEmpty) {
      return nonFlightPlaces.first;
    }

    // Check where waking up (previous night's sleep)
    if (previousSleepAt != null &&
        previousSleepAt.isNotEmpty &&
        previousSleepAt != 'Avión' &&
        previousSleepAt != 'Flight') {
      return previousSleepAt;
    }

    // Check today's sleep
    if (sleepAt.isNotEmpty && sleepAt != 'Avión' && sleepAt != 'Flight') {
      return sleepAt;
    }

    return null;
  }
}
