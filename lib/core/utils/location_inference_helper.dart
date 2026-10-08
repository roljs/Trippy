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
}
