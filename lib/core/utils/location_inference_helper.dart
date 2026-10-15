import 'city_color_helper.dart';
import '../../models/models.dart';

/// Helper to infer default country or location for a day based on the most
/// recent flight or transport booking in the itinerary.
class LocationInferenceHelper {
  /// Known airport and city mappings to countries
  static final Map<String, String> _knownKeywordsToCountry = {
    // Japan
    'japan': 'Japan',
    'tokyo': 'Japan',
    'kyoto': 'Japan',
    'osaka': 'Japan',
    'hnd': 'Japan',
    'nrt': 'Japan',
    'kix': 'Japan',
    'haneda': 'Japan',
    'narita': 'Japan',
    'shinkansen': 'Japan',

    // Italy
    'italy': 'Italy',
    'rome': 'Italy',
    'roma': 'Italy',
    'florence': 'Italy',
    'firenze': 'Italy',
    'positano': 'Italy',
    'amalfi': 'Italy',
    'naples': 'Italy',
    'napoli': 'Italy',
    'venice': 'Italy',
    'milan': 'Italy',
    'fco': 'Italy',
    'cia': 'Italy',
    'flr': 'Italy',
    'nap': 'Italy',
    'mxp': 'Italy',
    'frecciarossa': 'Italy',

    // USA
    'usa': 'United States',
    'united states': 'United States',
    'seattle': 'United States',
    'sea': 'United States',
    'san francisco': 'United States',
    'sfo': 'United States',
    'new york': 'United States',
    'jfk': 'United States',
    'ewr': 'United States',
    'lax': 'United States',
    'ord': 'United States',

    // France
    'france': 'France',
    'paris': 'France',
    'cdg': 'France',
    'ory': 'France',

    // UK
    'uk': 'United Kingdom',
    'united kingdom': 'United Kingdom',
    'london': 'United Kingdom',
    'lhr': 'United Kingdom',
    'lgw': 'United Kingdom',

    // Spain
    'spain': 'Spain',
    'madrid': 'Spain',
    'barcelona': 'Spain',
    'bcn': 'Spain',
    'mad': 'Spain',

    // Germany
    'germany': 'Germany',
    'berlin': 'Germany',
    'munich': 'Germany',
    'fra': 'Germany',
    'muc': 'Germany',
  };

  /// Extracts country name from a freeform location or airport string
  static String? extractCountry(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final lower = text.toLowerCase();

    // 1. Direct keyword match
    for (final entry in _knownKeywordsToCountry.entries) {
      final reg = RegExp(r'\b' + RegExp.escape(entry.key) + r'\b', caseSensitive: false);
      if (reg.hasMatch(lower)) {
        return entry.value;
      }
    }

    // 2. Comma separated country pattern (e.g. "City, Country" or "Airport (City, Country)")
    if (text.contains(',')) {
      final parts = text.split(',');
      final candidate = parts.last.replaceAll(RegExp(r'[\(\)]'), '').trim();
      if (candidate.isNotEmpty) {
        // Check if candidate matches any known country
        for (final entry in _knownKeywordsToCountry.entries) {
          if (candidate.toLowerCase() == entry.key) {
            return entry.value;
          }
        }
        return candidate;
      }
    }

    return null;
  }

  /// Determines default main location/country for the given day based on:
  /// 1. Most recent flight or transport activity up to the end of that day.
  /// 2. If none prior, the first upcoming flight's arrival country or trip destination country.
  static String inferTargetCountryForDay({
    required DateTime date,
    required List<Flight> flights,
    required List<Activity> activities,
    required String tripDestination,
  }) {
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    // Collect candidate events with timestamp and destination text
    final candidateEvents = <({DateTime time, String destinationText})>[];

    for (final f in flights) {
      if (f.arrivalTime.isBefore(endOfDay) || f.arrivalTime.isAtSameMomentAs(endOfDay)) {
        candidateEvents.add((time: f.arrivalTime, destinationText: f.arrivalAirport));
      }
      if (f.departureTime.isBefore(endOfDay) || f.departureTime.isAtSameMomentAs(endOfDay)) {
        candidateEvents.add((time: f.departureTime, destinationText: f.departureAirport));
      }
    }

    for (final a in activities) {
      if (a.category == ActivityCategory.transport) {
        final actDate = a.date;
        if (actDate.isBefore(endOfDay) || actDate.isAtSameMomentAs(endOfDay)) {
          final text = a.location ?? a.title;
          candidateEvents.add((time: a.startDateTime, destinationText: text));
        }
      }
    }

    // Sort by timestamp descending (most recent first)
    candidateEvents.sort((a, b) => b.time.compareTo(a.time));

    for (final ev in candidateEvents) {
      final country = extractCountry(ev.destinationText);
      if (country != null) return country;
    }

    // If no recent flight has occurred yet, check upcoming flights
    final futureFlights = flights
        .where((f) => f.departureTime.isAfter(endOfDay))
        .toList()
      ..sort((a, b) => a.departureTime.compareTo(b.departureTime));

    if (futureFlights.isNotEmpty) {
      final country = extractCountry(futureFlights.first.arrivalAirport);
      if (country != null) return country;
    }

    // Fallback to trip destination country
    final fallbackCountry = extractCountry(tripDestination);
    if (fallbackCountry != null) return fallbackCountry;

    return tripDestination.isNotEmpty ? tripDestination : 'Travel';
  }

  /// Extracts a candidate city from a freeform location/address string.
  static String? extractCityCandidate(
    String location, {
    required String defaultCountry,
    required Trip trip,
    List<Stay> stays = const [],
    List<Flight> flights = const [],
  }) {
    final parts = location
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;

    final countryLower = defaultCountry.toLowerCase();

    // Check comma parts from right to left (skipping country if present)
    for (int i = parts.length - 1; i >= 0; i--) {
      final part = parts[i];
      final partLower = part.toLowerCase();

      // Skip country names
      if (partLower == countryLower || isCountryName(partLower)) {
        continue;
      }

      if (isCity(part, trip: trip, stays: stays, flights: flights)) {
        return canonicalCityName(part);
      }
    }

    // Also check if any substring matches a known city from stays or flights
    for (final s in stays) {
      final stayCity = CityColorHelper.extractCityForStay(s);
      if (stayCity != null && stayCity.isNotEmpty) {
        if (location.toLowerCase().contains(stayCity.toLowerCase())) {
          return stayCity;
        }
      }
    }

    for (final f in flights) {
      final depCity = extractCityFromAirportString(f.departureAirport);
      if (depCity.isNotEmpty && location.toLowerCase().contains(depCity.toLowerCase())) {
        return depCity;
      }
      final arrCity = extractCityFromAirportString(f.arrivalAirport);
      if (arrCity.isNotEmpty && location.toLowerCase().contains(arrCity.toLowerCase())) {
        return arrCity;
      }
    }

    // If there is only one part or last non-country part and it's not a common non-city word
    if (parts.isNotEmpty) {
      final lastPart = parts.last;
      final candidate = (isCountryName(lastPart.toLowerCase()) && parts.length > 1)
          ? parts[parts.length - 2]
          : lastPart;
      if (!isCountryName(candidate.toLowerCase()) && !_isNonCityWord(candidate.toLowerCase())) {
        return canonicalCityName(candidate);
      }
    }

    return null;
  }

  static bool _isNonCityWord(String lower) {
    const nonCityKeywords = [
      'bay', 'bahia', 'bahía', 'cave', 'cueva', 'beach', 'playa',
      'island', 'islands', 'isla', 'islas', 'airport', 'aeropuerto',
      'terminal', 'gate', 'station', 'estacion', 'estación', 'pier',
      'port', 'harbor', 'harbour', 'puerto', 'dock', 'cruise',
      'crucero', 'boat', 'ferry', 'park', 'parque', 'lake', 'lago',
      'river', 'rio', 'río', 'mountain', 'montaña', 'mount', 'peak',
      'waterfall', 'cascada', 'temple', 'wat', 'pagoda', 'church',
      'cathedral', 'mosque', 'museum', 'museo', 'market', 'mercado',
      'bazaar', 'mall', 'resort', 'hotel', 'hostel', 'villa', 'palace',
      'palacio', 'castle', 'tower', 'bridge', 'puente', 'street',
      'road', 'avenue', 'boulevard', 'calle', 'plaza', 'square',
      'zoo', 'aquarium', 'sanctuary', 'bar', 'cafe', 'café',
      'restaurant', 'restaurante', 'shop', 'store', 'alley', 'lane',
    ];
    for (final kw in nonCityKeywords) {
      final reg = RegExp(r'\b' + RegExp.escape(kw) + r'\b', caseSensitive: false);
      if (reg.hasMatch(lower)) return true;
    }
    return false;
  }

  static bool isCity(
    String candidate, {
    required Trip trip,
    List<Stay> stays = const [],
    List<Flight> flights = const [],
  }) {
    final clean = candidate.trim();
    if (clean.isEmpty) return false;
    final lower = clean.toLowerCase();

    if (_isNonCityWord(lower)) return false;

    // 1. Matches city from trip stays
    for (final s in stays) {
      final c = CityColorHelper.extractCityForStay(s);
      if (c != null && c.isNotEmpty && c.toLowerCase() == lower) {
        return true;
      }
    }

    // 2. Matches trip start/end location
    if (trip.startLocation != null && trip.startLocation!.trim().toLowerCase() == lower) {
      return true;
    }
    if (trip.endLocation != null && trip.endLocation!.trim().toLowerCase() == lower) {
      return true;
    }

    // 3. Matches flights departure or arrival city
    for (final f in flights) {
      final depCity = extractCityFromAirportString(f.departureAirport).toLowerCase();
      if (depCity.isNotEmpty && (depCity == lower || lower.contains(depCity))) return true;
      final arrCity = extractCityFromAirportString(f.arrivalAirport).toLowerCase();
      if (arrCity.isNotEmpty && (arrCity == lower || lower.contains(arrCity))) return true;
    }

    // 4. Matches existing dayLocations in trip
    if (trip.dayLocations.isNotEmpty) {
      for (final locs in trip.dayLocations.values) {
        for (final l in locs) {
          if (l.trim().toLowerCase() == lower) return true;
        }
      }
    }

    // 5. Common travel cities
    const knownCities = {
      'bangkok', 'chiang mai', 'chiang rai', 'phuket', 'krabi', 'pattaya',
      'ayutthaya', 'hua hin', 'surat thani', 'koh samui', 'samui', 'hanoi',
      'ha long', 'halong', 'ninh binh', 'da nang', 'danang', 'hoi an', 'hue',
      'ho chi minh city', 'ho chi minh', 'saigon', 'can tho', 'hai phong',
      'siem reap', 'phnom penh', 'battambang', 'singapore', 'kuala lumpur',
      'penang', 'george town', 'tokyo', 'kyoto', 'osaka', 'hiroshima',
      'nara', 'yokohama', 'sapporo', 'fukuoka', 'nagoya', 'nikko', 'hakone',
      'kamakura', 'kanazawa', 'takayama', 'kobe', 'miyajima', 'okinawa',
      'seoul', 'busan', 'incheon', 'jeju', 'taipei', 'kaohsiung', 'hong kong',
      'macau', 'beijing', 'shanghai', 'london', 'paris', 'rome', 'milan',
      'florence', 'venice', 'barcelona', 'madrid', 'seville', 'amsterdam',
      'berlin', 'munich', 'vienna', 'prague', 'budapest', 'zurich', 'geneva',
      'bellevue', 'seattle', 'portland', 'vancouver', 'san francisco',
      'los angeles', 'san diego', 'las vegas', 'new york', 'boston',
      'chicago', 'miami', 'orlando', 'honolulu', 'denver', 'austin',
    };

    return knownCities.contains(lower);
  }

  static bool isCountryName(String lower) {
    const countries = {
      'thailand', 'japan', 'vietnam', 'cambodia', 'singapore',
      'south korea', 'korea', 'usa', 'united states', 'france',
      'italy', 'germany', 'spain', 'uk', 'united kingdom',
      'indonesia', 'malaysia', 'philippines', 'mexico', 'canada',
      'australia', 'new zealand', 'china', 'india', 'taiwan',
    };
    return countries.contains(lower);
  }

  static String extractCityFromAirportString(String str) {
    if (str.contains('(') && str.contains(')')) {
      final start = str.indexOf('(') + 1;
      final end = str.indexOf(')');
      if (end > start) {
        final inside = str.substring(start, end).trim();
        if (inside.length == 3 && inside.toUpperCase() == inside) {
          return str.substring(0, start - 1).trim();
        }
        return inside;
      }
    }
    return str.replaceAll(RegExp(r'\b[A-Z]{3}\b'), '').trim();
  }

  static String canonicalCityName(String text) {
    final lower = text.trim().toLowerCase();
    if (lower == 'ha long' || lower == 'halong') return 'Ha Long';
    if (lower == 'ninh binh') return 'Ninh Binh';
    if (lower == 'chiang mai') return 'Chiang Mai';
    if (lower == 'chiang rai') return 'Chiang Rai';
    if (lower == 'siem reap') return 'Siem Reap';
    if (lower == 'ho chi minh city' || lower == 'ho chi minh' || lower == 'saigon') return 'Ho Chi Minh City';
    if (lower == 'da nang' || lower == 'danang') return 'Da Nang';
    if (lower == 'hoi an') return 'Hoi An';
    if (lower == 'san francisco') return 'San Francisco';
    if (lower == 'new york') return 'New York';
    if (lower == 'los angeles') return 'Los Angeles';
    if (lower == 'las vegas') return 'Las Vegas';
    if (lower == 'kuala lumpur') return 'Kuala Lumpur';
    if (lower == 'hong kong') return 'Hong Kong';
    return text.trim().split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }
}
