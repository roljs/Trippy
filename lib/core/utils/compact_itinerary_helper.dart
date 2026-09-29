import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import 'city_color_helper.dart';
import 'location_inference_helper.dart';

/// Data representation for a single day in the Compact View table
class CompactDaySummary {
  final DateTime date;
  final int dayNumber;
  final String formattedDate;
  final String dayOfWeek;
  final String placesToVisit;
  final String sleepAt;
  final Stay? stayTonight;
  final Flight? flightTonight;
  final String notes;
  final Color rowColor;
  final List<Activity> activities;
  final List<Flight> flights;

  const CompactDaySummary({
    required this.date,
    required this.dayNumber,
    required this.formattedDate,
    required this.dayOfWeek,
    required this.placesToVisit,
    required this.sleepAt,
    this.stayTonight,
    this.flightTonight,
    required this.notes,
    required this.rowColor,
    this.activities = const [],
    this.flights = const [],
  });
}

/// Helper to generate day-by-day compact tabular summaries for any trip
class CompactItineraryHelper {
  static const Color colorJapan = Color(0xFFE2F0D9); // Soft pastel green
  static const Color colorVietnam = Color(0xFFDDEBF7); // Soft pastel sky blue
  static const Color colorCambodia = Color(0xFFFCE4D6); // Soft pastel peach
  static const Color colorThailand = Color(0xFFE8D7F1); // Soft pastel lavender
  static const Color colorSingapore = Color(0xFFD9E1F2); // Soft pastel periwinkle
  static const Color colorKorea = Color(0xFFEDEDED); // Soft pastel cool gray
  static const Color colorDefaultNeutral = Color(0xFFFFFFFF); // Clean white

  static final List<Color> _rotatingPastelColors = [
    const Color(0xFFE2F0D9),
    const Color(0xFFDDEBF7),
    const Color(0xFFFCE4D6),
    const Color(0xFFE8D7F1),
    const Color(0xFFD9E1F2),
    const Color(0xFFFFF2CC),
    const Color(0xFFEDEDED),
  ];

  /// Detects if a trip has Spanish metadata or language preference
  static bool isSpanishTrip(Trip trip) {
    final text = '${trip.title} ${trip.destination}'.toLowerCase();
    return text.contains('thailandia') ||
        text.contains('viaje') ||
        text.contains('itinerario') ||
        trip.id.toLowerCase().contains('thai');
  }

  /// Formats day of the week according to language
  static String formatDayOfWeek(DateTime date, {required bool isSpanish}) {
    if (isSpanish) {
      switch (date.weekday) {
        case DateTime.monday:
          return 'Lunes';
        case DateTime.tuesday:
          return 'Martes';
        case DateTime.wednesday:
          return 'Miércoles';
        case DateTime.thursday:
          return 'Jueves';
        case DateTime.friday:
          return 'Viernes';
        case DateTime.saturday:
          return 'Sábado';
        case DateTime.sunday:
          return 'Domingo';
      }
    }
    return DateFormat('EEEE').format(date);
  }

  /// Formats date cleanly as "1-Nov", "2-Nov", etc.
  static String formatDate(DateTime date) {
    return DateFormat('d-MMM').format(date);
  }

  /// Normalizes date to midnight for pure calendar day comparisons
  static DateTime _normalize(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Checks if two DateTimes represent the same calendar day
  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Generates the list of [CompactDaySummary] for the given trip
  static List<CompactDaySummary> generateSummaries({
    required Trip trip,
    required List<Stay> stays,
    required List<Flight> flights,
    required Map<DateTime, List<Activity>> activitiesByDay,
    bool isSpanish = false, // All columns must default to English
  }) {
    final days = trip.daysList;
    if (days.isEmpty) return const [];

    // 1. Precompute Night Sleep Location & Stay for each calendar day
    final Map<int, ({String sleepAt, Stay? stay, Flight? flight})> nightSleepMap = {};

    for (int i = 0; i < days.length; i++) {
      final date = _normalize(days[i]);

      // Check if night is spent on an overnight flight
      final overnightFlight = flights.where((f) {
        final depDate = _normalize(f.departureTime);
        final arrDate = _normalize(f.arrivalTime);
        return (f.isOvernight || f.isNightStay || arrDate.isAfter(depDate)) &&
            _isSameDay(depDate, date);
      }).firstOrNull;

      if (overnightFlight != null) {
        final label = isSpanish ? 'Avión' : 'Flight';
        nightSleepMap[i] = (sleepAt: label, stay: null, flight: overnightFlight);
        continue;
      }

      // Check if covered by a Stay
      Stay? coveringStay;
      for (final s in stays) {
        final inDate = _normalize(s.checkInDate);
        final outDate = _normalize(s.checkOutDate);
        if ((inDate.isBefore(date) || inDate.isAtSameMomentAs(date)) &&
            outDate.isAfter(date)) {
          coveringStay = s;
          break;
        }
      }

      if (coveringStay != null) {
        if (coveringStay.type == StayType.overnightFlight) {
          final label = isSpanish ? 'Avión' : 'Flight';
          nightSleepMap[i] = (
            sleepAt: label,
            stay: coveringStay,
            flight: coveringStay.overnightFlight,
          );
        } else {
          final cityName = _resolveCityFromStayOrTrip(
            stay: coveringStay,
            trip: trip,
            date: date,
            isSpanish: isSpanish,
          );
          nightSleepMap[i] = (
            sleepAt: cityName,
            stay: coveringStay,
            flight: coveringStay.overnightFlight,
          );
        }
        continue;
      }

      // If last day of trip and has return flight arriving home
      if (i == days.length - 1) {
        final departureFlight = flights
            .where((f) => f.isMainDeparture || _isSameDay(_normalize(f.departureTime), date))
            .lastOrNull;
        if (departureFlight != null) {
          final arrCity = _extractCityFromAirportString(departureFlight.arrivalAirport);
          if (arrCity.isNotEmpty) {
            nightSleepMap[i] = (
              sleepAt: _normalizeCityName(arrCity, isSpanish: isSpanish),
              stay: null,
              flight: departureFlight,
            );
            continue;
          }
        }
      }

      // Fallback: check custom day locations or trip destination
      final customLocs = trip.getCustomLocationsForDate(date);
      if (customLocs != null && customLocs.isNotEmpty) {
        final city = _normalizeCityName(customLocs.last, isSpanish: isSpanish);
        nightSleepMap[i] = (sleepAt: city, stay: null, flight: null);
      } else {
        final country = LocationInferenceHelper.inferTargetCountryForDay(
          date: date,
          flights: flights,
          activities: activitiesByDay[date] ?? [],
          tripDestination: trip.destination,
        );
        nightSleepMap[i] = (sleepAt: _normalizeCityName(country, isSpanish: isSpanish), stay: null, flight: null);
      }
    }

    // 2. Build Day Summaries with transitions and notes
    final List<CompactDaySummary> summaries = [];
    final Map<String, Color> countryColorAssignments = {};
    int nextColorIdx = 0;

    for (int i = 0; i < days.length; i++) {
      final date = _normalize(days[i]);
      final dayNumber = i + 1;
      final formattedDate = formatDate(date);
      final dayOfWeek = formatDayOfWeek(date, isSpanish: isSpanish);
      final dayActivities = activitiesByDay[date] ?? [];
      final dayFlights = flights.where((f) {
        final dep = _normalize(f.departureTime);
        final arr = _normalize(f.arrivalTime);
        return _isSameDay(dep, date) || _isSameDay(arr, date);
      }).toList();

      final tonightSleep = nightSleepMap[i];
      final prevTonightSleep = i > 0 ? nightSleepMap[i - 1] : null;

      // Determine Places to Visit
      final placesToVisit = _determinePlacesToVisit(
        dayIndex: i,
        totalDays: days.length,
        date: date,
        trip: trip,
        tonightSleep: tonightSleep?.sleepAt ?? '',
        previousSleep: prevTonightSleep?.sleepAt,
        dayFlights: dayFlights,
        dayActivities: dayActivities,
        isSpanish: isSpanish,
      );

      // Determine Succinct Notes
      final notes = _determineDayNotes(
        dayIndex: i,
        date: date,
        dayFlights: dayFlights,
        dayActivities: dayActivities,
        isSpanish: isSpanish,
      );

      // Determine Row Color (driven by Sleep At city)
      final rowColor = _determineRowColor(
        dayIndex: i,
        totalDays: days.length,
        date: date,
        trip: trip,
        dayFlights: dayFlights,
        dayActivities: dayActivities,
        sleepAt: tonightSleep?.sleepAt ?? '',
        placesToVisit: placesToVisit,
        previousSleep: prevTonightSleep?.sleepAt,
        countryColorAssignments: countryColorAssignments,
        nextColorIdxGetter: () => nextColorIdx++,
      );

      summaries.add(
        CompactDaySummary(
          date: date,
          dayNumber: dayNumber,
          formattedDate: formattedDate,
          dayOfWeek: dayOfWeek,
          placesToVisit: placesToVisit,
          sleepAt: tonightSleep?.sleepAt ?? '',
          stayTonight: tonightSleep?.stay,
          flightTonight: tonightSleep?.flight,
          notes: notes,
          rowColor: rowColor,
          activities: dayActivities,
          flights: dayFlights,
        ),
      );
    }

    return summaries;
  }

  /// Determines comma-separated summary of places to visit on a specific day
  static String _determinePlacesToVisit({
    required int dayIndex,
    required int totalDays,
    required DateTime date,
    required Trip trip,
    required String tonightSleep,
    required String? previousSleep,
    required List<Flight> dayFlights,
    required List<Activity> dayActivities,
    required bool isSpanish,
  }) {
    final places = <String>[];

    // Case A: Day 1 with overnight arrival flight departing today
    if (dayIndex == 0) {
      final departingFlight = dayFlights.where((f) {
        return _isSameDay(_normalize(f.departureTime), date);
      }).firstOrNull;

      if (departingFlight != null && departingFlight.isOvernight) {
        return isSpanish ? 'Volar' : 'Fly';
      }
    }

    // Case B: Day 2 arriving from an overnight flight
    if (dayIndex == 1 && previousSleep == (isSpanish ? 'Avión' : 'Flight')) {
      final arrFlight = dayFlights.where((f) {
        return _isSameDay(_normalize(f.arrivalTime), date);
      }).firstOrNull;

      final flightPrefix = isSpanish ? 'Volar' : 'Flight';
      final city = arrFlight != null
          ? _normalizeCityName(_extractCityFromAirportString(arrFlight.arrivalAirport), isSpanish: isSpanish)
          : tonightSleep;
      return '$flightPrefix, $city';
    }

    // Case C: Final Day returning home
    if (dayIndex == totalDays - 1) {
      final returnFlight = dayFlights.where((f) {
        return _isSameDay(_normalize(f.departureTime), date);
      }).firstOrNull;

      if (returnFlight != null) {
        final origin = previousSleep ??
            _normalizeCityName(_extractCityFromAirportString(returnFlight.departureAirport), isSpanish: isSpanish);
        final transit = isSpanish ? 'Avion' : 'Flight';
        final dest = _normalizeCityName(_extractCityFromAirportString(returnFlight.arrivalAirport), isSpanish: isSpanish);
        return '$origin, $transit, $dest';
      }
    }

    // Case D: Inter-city moves on flight days
    final moveFlights = dayFlights.where((f) {
      final dep = _normalize(f.departureTime);
      final arr = _normalize(f.arrivalTime);
      return _isSameDay(dep, date) && _isSameDay(arr, date);
    }).toList();

    if (moveFlights.isNotEmpty) {
      final f = moveFlights.first;
      final depCity = _normalizeCityName(_extractCityFromAirportString(f.departureAirport), isSpanish: isSpanish);
      final arrCity = _normalizeCityName(_extractCityFromAirportString(f.arrivalAirport), isSpanish: isSpanish);
      if (depCity.isNotEmpty && arrCity.isNotEmpty && depCity != arrCity) {
        places.add(depCity);
        places.add(arrCity);
        return places.join(', ');
      }
    }

    // Case E: Transition between different stays / cities
    if (previousSleep != null &&
        previousSleep.isNotEmpty &&
        tonightSleep.isNotEmpty &&
        previousSleep != tonightSleep &&
        previousSleep != 'Avión' &&
        previousSleep != 'Flight') {
      places.add(previousSleep);

      // Check intermediate stop from activities (e.g. "Halong Bay, Ninh Bin" or "Nikko")
      for (final a in dayActivities) {
        final text = '${a.title} ${a.location ?? ''}';
        final lower = text.toLowerCase();
        if (lower.contains('ninh bin') && !places.contains('Ninh Bin')) {
          places.add('Ninh Bin');
        }
      }

      if (!places.contains(tonightSleep)) {
        places.add(tonightSleep);
      }
      return places.join(', ');
    }

    // Case F: Check if day activities include travel between two cities (e.g., Nikko to Tokyo, or Ha Long to Hanoi)
    for (final a in dayActivities) {
      if (a.category == ActivityCategory.transport) {
        final text = '${a.title} ${a.location ?? ''}'.toLowerCase();
        if (text.contains('nikko') && text.contains('tokyo')) {
          if (text.contains('return') || text.contains('to tokyo')) {
            return 'Nikko, Tokyo';
          } else {
            return 'Tokyo, Nikko';
          }
        }
        if (text.contains('ninh bin') && text.contains('hanoi')) {
          return 'Ninh Bin, Hanoi';
        }
        if (text.contains('ha long') && text.contains('ninh bin')) {
          return 'Halong Bay, Ninh Bin';
        }
        if (text.contains('hanoi') && text.contains('ha long')) {
          return 'Hanoi, HaLong Bay Cruise';
        }
      }
    }

    // Check custom day locations
    final customLocs = trip.getCustomLocationsForDate(date);
    if (customLocs != null && customLocs.length > 1) {
      // Exclude country name if it's the first element
      final cityParts = customLocs.sublist(1);
      final mapped = cityParts.map((c) => _normalizeCityName(c, isSpanish: isSpanish)).toSet();
      if (mapped.isNotEmpty) {
        return mapped.join(', ');
      }
    }

    // Single city day
    if (tonightSleep.isNotEmpty) {
      return tonightSleep;
    }

    return trip.destination;
  }

  /// Determines succinct day notes (flight times/reference, key activities)
  static String _determineDayNotes({
    required int dayIndex,
    required DateTime date,
    required List<Flight> dayFlights,
    required List<Activity> dayActivities,
    required bool isSpanish,
  }) {
    // 1. Flight info taking priority
    final arrivingOvernightFlight = dayFlights.where((f) {
      final arr = _normalize(f.arrivalTime);
      final dep = _normalize(f.departureTime);
      return _isSameDay(arr, date) && arr.isAfter(dep);
    }).firstOrNull;

    if (arrivingOvernightFlight != null) {
      final arrTimeStr = DateFormat('h:mma').format(arrivingOvernightFlight.arrivalTime).toLowerCase();
      final airport = arrivingOvernightFlight.arrivalAirport.split(' ').first;
      if (isSpanish) {
        return 'Llega a las $arrTimeStr a $airport';
      } else {
        return 'Arrives at $arrTimeStr at $airport';
      }
    }

    final departingFlight = dayFlights.where((f) {
      return _isSameDay(_normalize(f.departureTime), date);
    }).firstOrNull;

    if (departingFlight != null) {
      if (departingFlight.notes != null && departingFlight.notes!.trim().isNotEmpty) {
        final note = departingFlight.notes!.trim();
        if (departingFlight.isOvernight) {
          final depTimeStr = DateFormat('h:mma').format(departingFlight.departureTime).toLowerCase();
          final depA = _extractCityFromAirportString(departingFlight.departureAirport);
          if (!isSpanish) {
            return '${departingFlight.flightNumber} Departs at $depTimeStr from $depA';
          }
          if (note.contains(',')) {
            final parts = note.split(',');
            return parts.first.trim();
          }
        }

        if (!isSpanish && (note.toLowerCase().contains('sale') || note.toLowerCase().contains('llega'))) {
          final depTimeStr = DateFormat('h:mma').format(departingFlight.departureTime).toLowerCase();
          final arrTimeStr = DateFormat('h:mma').format(departingFlight.arrivalTime).toLowerCase();
          final depA = departingFlight.departureAirport.split(' ').first;
          final arrA = departingFlight.arrivalAirport.split(' ').first;
          return '${departingFlight.airline}, Dep $depA $depTimeStr, Arr $arrA $arrTimeStr';
        }

        return note;
      } else {
        final depTimeStr = DateFormat('h:mma').format(departingFlight.departureTime).toLowerCase();
        final arrTimeStr = DateFormat('h:mma').format(departingFlight.arrivalTime).toLowerCase();
        final fltNum = departingFlight.flightNumber.isNotEmpty ? ' ${departingFlight.flightNumber}' : '';
        final airline = '${departingFlight.airline}$fltNum';
        final depA = departingFlight.departureAirport.split(' ').first;
        final arrA = departingFlight.arrivalAirport.split(' ').first;
        if (isSpanish) {
          return '$airline, Sale $depA $depTimeStr y llega a $arrA $arrTimeStr';
        } else {
          return '$airline, Dep $depA $depTimeStr, Arr $arrA $arrTimeStr';
        }
      }
    }

    // 2. Activities notes (e.g. Puppet show or specific scheduled activity note)
    for (final a in dayActivities) {
      final titleLower = a.title.toLowerCase();
      if (titleLower.contains('puppet show') || titleLower.contains('show')) {
        return a.title;
      }
      if (a.notes != null && a.notes!.trim().isNotEmpty) {
        final note = a.notes!.trim();
        if (note.toLowerCase().contains('puppet show') ||
            note.toLowerCase().contains('regresando') ||
            note.toLowerCase().contains('seats') ||
            note.toLowerCase().contains('high-speed') ||
            note.toLowerCase().contains('sunrise')) {
          return note;
        }
      }
    }

    return '';
  }

  /// Determines pastel background row color driven directly by the "Sleep At" City of the row.
  /// Overnight flight nights use [CityColorHelper.flightPastel].
  static Color _determineRowColor({
    required int dayIndex,
    required int totalDays,
    required DateTime date,
    required Trip trip,
    required List<Flight> dayFlights,
    required List<Activity> dayActivities,
    required String sleepAt,
    required String placesToVisit,
    required String? previousSleep,
    required Map<String, Color> countryColorAssignments,
    required int Function() nextColorIdxGetter,
  }) {
    final sLower = sleepAt.toLowerCase().trim();

    // 1. Overnight flight sleep
    if (sLower == 'flight' || sLower == 'avión' || sLower == 'avion') {
      return CityColorHelper.flightPastel;
    }

    // 2. Driven by "Sleep At" City of the row
    if (sleepAt.isNotEmpty) {
      return CityColorHelper.getPastelColorForCity(sleepAt);
    }

    // 3. Fallback to target country inference
    final targetCountry = LocationInferenceHelper.inferTargetCountryForDay(
      date: date,
      flights: dayFlights,
      activities: dayActivities,
      tripDestination: trip.destination,
    );

    return countryColorAssignments.putIfAbsent(targetCountry, () {
      final idx = nextColorIdxGetter() % _rotatingPastelColors.length;
      return _rotatingPastelColors[idx];
    });
  }

  /// Extracts city name from stay details or trip metadata
  static String _resolveCityFromStayOrTrip({
    required Stay stay,
    required Trip trip,
    required DateTime date,
    required bool isSpanish,
  }) {
    final nameLower = stay.name.toLowerCase();
    final addrLower = stay.address?.toLowerCase() ?? '';

    if (nameLower.contains('cruise') || nameLower.contains('crucero')) {
      return 'Halong Bay Cruise';
    }
    if (nameLower.contains('nikko') || addrLower.contains('nikko')) {
      return 'Nikko';
    }
    if (nameLower.contains('tokyo') || addrLower.contains('tokyo')) {
      return 'Tokyo';
    }
    if (nameLower.contains('hanoi') || addrLower.contains('hanoi')) {
      return 'Hanoi';
    }
    if (nameLower.contains('ninh bin') || addrLower.contains('ninh bin')) {
      return 'Ninh Bin';
    }
    if (nameLower.contains('siem reap') || addrLower.contains('siem reap')) {
      return isSpanish ? 'Siem Reap' : 'Siem Reap';
    }
    if (nameLower.contains('bangkok') || addrLower.contains('bangkok')) {
      return 'Bangkok';
    }
    if (nameLower.contains('singapore') || addrLower.contains('singapore')) {
      return isSpanish ? 'Singapur' : 'Singapore';
    }
    if (nameLower.contains('seoul') || addrLower.contains('seoul') || addrLower.contains('korea')) {
      return isSpanish ? 'Corea' : 'Seoul';
    }
    if (nameLower.contains('rome') || addrLower.contains('roma')) {
      return 'Rome';
    }
    if (nameLower.contains('florence') || addrLower.contains('firenze')) {
      return 'Florence';
    }
    if (nameLower.contains('positano') || addrLower.contains('amalfi')) {
      return 'Positano';
    }
    if (nameLower.contains('naples') || addrLower.contains('napoli')) {
      return 'Naples';
    }
    if (nameLower.contains('kyoto') || addrLower.contains('kyoto')) {
      return 'Kyoto';
    }

    // Try custom day locations
    final custom = trip.getCustomLocationsForDate(date);
    if (custom != null && custom.isNotEmpty) {
      return _normalizeCityName(custom.last, isSpanish: isSpanish);
    }

    // Try stay name first segment
    return stay.name;
  }

  /// Normalizes city spelling for English or Spanish
  static String _normalizeCityName(String text, {required bool isSpanish}) {
    final clean = text.trim();
    final lower = clean.toLowerCase();

    if (lower.contains('tokyo')) return 'Tokyo';
    if (lower.contains('nikko')) return 'Nikko';
    if (lower.contains('hanoi')) return 'Hanoi';
    if (lower.contains('siem reap') || lower.contains('angkor')) {
      return 'Siem Reap';
    }
    if (lower.contains('bangkok')) return 'Bangkok';
    if (lower.contains('singapore') || lower.contains('singapur') || lower.contains('changi')) {
      return isSpanish ? 'Singapur' : 'Singapore';
    }
    if (lower.contains('seoul') || lower.contains('south korea') || lower.contains('incheon') || lower.contains('corea')) {
      return isSpanish ? 'Corea' : 'Seoul';
    }
    if (lower.contains('ninh bin')) return 'Ninh Bin';
    if (lower.contains('ha long') || lower.contains('halong')) {
      return 'Halong Bay Cruise';
    }
    if (lower.contains('seattle')) return 'Seattle';
    if (lower.contains('rome') || lower.contains('roma') || lower.contains('fiumicino')) return 'Rome';
    if (lower.contains('florence') || lower.contains('firenze')) return 'Florence';
    if (lower.contains('positano') || lower.contains('amalfi')) return 'Positano';
    if (lower.contains('naples') || lower.contains('napoli')) return 'Naples';
    if (lower.contains('kyoto')) return 'Kyoto';
    if (lower.contains('osaka')) return 'Osaka';

    return clean;
  }

  /// Extracts city name from airport label e.g. "SEA (Seattle)" -> "Seattle"
  static String _extractCityFromAirportString(String str) {
    if (str.contains('(') && str.contains(')')) {
      final start = str.indexOf('(') + 1;
      final end = str.indexOf(')');
      if (end > start) {
        return str.substring(start, end).trim();
      }
    }
    final parts = str.split(' ');
    if (parts.length > 1) {
      return parts.last.trim();
    }
    return str.trim();
  }
}
