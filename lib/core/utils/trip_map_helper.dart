import 'dart:math' as math;
import 'dart:ui';
import '../../models/models.dart';
import 'city_color_helper.dart';

/// Represents geographic coordinates (latitude and longitude).
class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint(this.lat, this.lng);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPoint &&
          runtimeType == other.runtimeType &&
          (lat - other.lat).abs() < 0.0001 &&
          (lng - other.lng).abs() < 0.0001;

  @override
  int get hashCode => Object.hash(lat.toStringAsFixed(3), lng.toStringAsFixed(3));
}

/// Represents a city visited along the chronological itinerary route.
class TripMapCityNode {
  final int sequenceNumber;
  final String cityName;
  final String? countryName;
  final GeoPoint coordinates;
  final DateTime? arrivalDate;
  final DateTime? departureDate;
  final int totalNights;
  final List<Stay> stays;
  final List<Activity> activities;
  final bool isOriginOrReturn;
  final int visitIndex;
  final int totalVisitsToThisCity;
  final Offset calloutOffset;

  const TripMapCityNode({
    required this.sequenceNumber,
    required this.cityName,
    this.countryName,
    required this.coordinates,
    this.arrivalDate,
    this.departureDate,
    required this.totalNights,
    required this.stays,
    required this.activities,
    this.isOriginOrReturn = false,
    this.visitIndex = 0,
    this.totalVisitsToThisCity = 1,
    this.calloutOffset = Offset.zero,
  });

  TripMapCityNode copyWith({
    int? sequenceNumber,
    String? cityName,
    String? countryName,
    GeoPoint? coordinates,
    DateTime? arrivalDate,
    DateTime? departureDate,
    int? totalNights,
    List<Stay>? stays,
    List<Activity>? activities,
    bool? isOriginOrReturn,
    int? visitIndex,
    int? totalVisitsToThisCity,
    Offset? calloutOffset,
  }) {
    return TripMapCityNode(
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      cityName: cityName ?? this.cityName,
      countryName: countryName ?? this.countryName,
      coordinates: coordinates ?? this.coordinates,
      arrivalDate: arrivalDate ?? this.arrivalDate,
      departureDate: departureDate ?? this.departureDate,
      totalNights: totalNights ?? this.totalNights,
      stays: stays ?? this.stays,
      activities: activities ?? this.activities,
      isOriginOrReturn: isOriginOrReturn ?? this.isOriginOrReturn,
      visitIndex: visitIndex ?? this.visitIndex,
      totalVisitsToThisCity: totalVisitsToThisCity ?? this.totalVisitsToThisCity,
      calloutOffset: calloutOffset ?? this.calloutOffset,
    );
  }
}

/// Represents a chronological connection (flight or ground transit) between two cities.
class TripMapConnectionLeg {
  final int sequenceIndex;
  final TripMapCityNode fromCity;
  final TripMapCityNode toCity;
  final Flight? flight;
  final Activity? transportActivity;
  final String moniker;
  final bool isFlight;
  final DateTime? departureTime;
  final DateTime? arrivalTime;

  const TripMapConnectionLeg({
    required this.sequenceIndex,
    required this.fromCity,
    required this.toCity,
    this.flight,
    this.transportActivity,
    required this.moniker,
    required this.isFlight,
    this.departureTime,
    this.arrivalTime,
  });
}

/// Full extracted map route for a trip with all nodes, connection legs, and bounding box.
class TripMapRoute {
  final List<TripMapCityNode> cities;
  final List<TripMapConnectionLeg> legs;
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
  final bool crossesPacific;

  const TripMapRoute({
    required this.cities,
    required this.legs,
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
    required this.crossesPacific,
  });

  bool get isEmpty => cities.isEmpty;
}

/// Helper for extracting geographic coordinates, cities, and chronological routes.
class TripMapHelper {
  // Built-in geographic coordinate database of worldwide travel cities and airport hubs
  static const Map<String, GeoPoint> _knownCoordinates = {
    // North America & Greater Seattle
    'seattle': GeoPoint(47.6062, -122.3321),
    'sea': GeoPoint(47.4502, -122.3088),
    'sea airport': GeoPoint(47.4502, -122.3088),
    'seatac': GeoPoint(47.4436, -122.2961),
    'seattle-tacoma': GeoPoint(47.4502, -122.3088),
    'seattle-tacoma international airport': GeoPoint(47.4502, -122.3088),
    'delta sky lounge': GeoPoint(47.4502, -122.3088),
    'bellevue': GeoPoint(47.6101, -122.2015),
    '3942 west lake sammish': GeoPoint(47.5747, -122.1093),
    '3942 west lake sammamish': GeoPoint(47.5747, -122.1093),
    'west lake sammish': GeoPoint(47.5747, -122.1093),
    'west lake sammamish': GeoPoint(47.5747, -122.1093),
    'lake sammamish': GeoPoint(47.5747, -122.1093),
    'lake sammish': GeoPoint(47.5747, -122.1093),
    'sammamish': GeoPoint(47.6163, -122.0356),
    'sammish': GeoPoint(47.5747, -122.1093),
    'redmond': GeoPoint(47.6740, -122.1215),
    'kirkland': GeoPoint(47.6769, -122.2060),
    'renton': GeoPoint(47.4829, -122.2171),
    'tacoma': GeoPoint(47.2529, -122.4443),
    'everett': GeoPoint(47.9790, -122.2021),
    'olympia': GeoPoint(47.0379, -122.9007),
    'spokane': GeoPoint(47.6588, -117.4260),
    'portland': GeoPoint(45.5152, -122.6784),
    'pdx': GeoPoint(45.5898, -122.5951),
    'washington park arboretum': GeoPoint(47.6298, -122.2947),
    'seattle arboretum': GeoPoint(47.6298, -122.2947),
    'san francisco': GeoPoint(37.7749, -122.4194),
    'sfo': GeoPoint(37.6213, -122.3790),
    'san jose': GeoPoint(37.3382, -121.8863),
    'sjc': GeoPoint(37.3639, -121.9289),
    'oakland': GeoPoint(37.8044, -122.2712),
    'oak': GeoPoint(37.7214, -122.2208),
    'los angeles': GeoPoint(34.0522, -118.2437),
    'lax': GeoPoint(33.9416, -118.4085),
    'san diego': GeoPoint(32.7157, -117.1611),
    'san': GeoPoint(32.7338, -117.1933),
    'new york': GeoPoint(40.7128, -74.0060),
    'jfk': GeoPoint(40.6413, -73.7781),
    'ewr': GeoPoint(40.6895, -74.1745),
    'chicago': GeoPoint(41.8781, -87.6298),
    'ord': GeoPoint(41.9742, -87.9073),
    'honolulu': GeoPoint(21.3069, -157.8583),
    'hnl': GeoPoint(21.3245, -157.9251),
    'las vegas': GeoPoint(36.1699, -115.1398),
    'las': GeoPoint(36.0840, -115.1537),
    'denver': GeoPoint(39.7392, -104.9903),
    'den': GeoPoint(39.8561, -104.6737),
    'boston': GeoPoint(42.3601, -71.0589),
    'bos': GeoPoint(42.3656, -71.0096),
    'miami': GeoPoint(25.7617, -80.1918),
    'mia': GeoPoint(25.7959, -80.2870),
    'vancouver': GeoPoint(49.2827, -123.1207),
    'yvr': GeoPoint(49.1967, -123.1815),
    'toronto': GeoPoint(43.6532, -79.3832),
    'yyz': GeoPoint(43.6777, -79.6248),
    'mexico city': GeoPoint(19.4326, -99.1332),
    'cancun': GeoPoint(21.1619, -86.8515),

    // Japan & East Asia
    'tokyo': GeoPoint(35.6762, 139.6503),
    'asakusa': GeoPoint(35.7118, 139.7967),
    'asakusa station': GeoPoint(35.7106, 139.7975),
    'tawaramachi': GeoPoint(35.7099, 139.7909),
    'apa hotel asakusa': GeoPoint(35.7100, 139.7915),
    'sensoji': GeoPoint(35.7148, 139.7967),
    'senso-ji': GeoPoint(35.7148, 139.7967),
    'shinjuku': GeoPoint(35.6938, 139.7034),
    'shibuya': GeoPoint(35.6580, 139.7016),
    'ginza': GeoPoint(35.6719, 139.7648),
    'ueno': GeoPoint(35.7141, 139.7741),
    'akihabara': GeoPoint(35.6983, 139.7731),
    'roppongi': GeoPoint(35.6628, 139.7314),
    'koduchi no yado': GeoPoint(36.7580, 139.5970),
    'tsurukamedaikichi': GeoPoint(36.7580, 139.5970),
    'hnd': GeoPoint(35.5494, 139.7798),
    'nrt': GeoPoint(35.7720, 140.3929),
    'nikko': GeoPoint(36.7551, 139.5989),
    'kyoto': GeoPoint(35.0116, 135.7681),
    'osaka': GeoPoint(34.6937, 135.5023),
    'kix': GeoPoint(34.4320, 135.2304),
    'itm': GeoPoint(34.7855, 135.4382),
    'sapporo': GeoPoint(43.0618, 141.3545),
    'cts': GeoPoint(42.7752, 141.6923),
    'hiroshima': GeoPoint(34.3853, 132.4553),
    'fukuoka': GeoPoint(33.5904, 130.4017),
    'fuk': GeoPoint(33.5859, 130.4507),
    'okinawa': GeoPoint(26.2124, 127.6809),
    'naha': GeoPoint(26.2124, 127.6809),
    'seoul': GeoPoint(37.5665, 126.9780),
    'icn': GeoPoint(37.4602, 126.4407),
    'gmp': GeoPoint(37.5583, 126.7906),
    'busan': GeoPoint(35.1796, 129.0756),
    'pus': GeoPoint(35.1795, 128.9382),
    'jeju': GeoPoint(33.4996, 126.5312),
    'taipei': GeoPoint(25.0330, 121.5654),
    'tpe': GeoPoint(25.0797, 121.2342),
    'hong kong': GeoPoint(22.3193, 114.1694),
    'hkg': GeoPoint(22.3080, 113.9185),
    'beijing': GeoPoint(39.9042, 116.4074),
    'pek': GeoPoint(40.0799, 116.6031),
    'pkx': GeoPoint(39.5098, 116.4105),
    'shanghai': GeoPoint(31.2304, 121.4737),
    'pvg': GeoPoint(31.1443, 121.8083),

    // Southeast Asia
    'hanoi': GeoPoint(21.0285, 105.8542),
    'han': GeoPoint(21.2212, 105.8072),
    'ha long bay': GeoPoint(20.9101, 107.1839),
    'ha long': GeoPoint(20.9101, 107.1839),
    'halong': GeoPoint(20.9101, 107.1839),
    'ninh binh': GeoPoint(20.2506, 105.9745),
    'da nang': GeoPoint(16.0544, 108.2022),
    'dad': GeoPoint(16.0439, 108.1994),
    'hoi an': GeoPoint(15.8801, 108.3380),
    'hue': GeoPoint(16.4637, 107.5909),
    'ho chi minh': GeoPoint(10.8231, 106.6297),
    'ho chi minh city': GeoPoint(10.8231, 106.6297),
    'saigon': GeoPoint(10.8231, 106.6297),
    'sgn': GeoPoint(10.8188, 106.6519),
    'siem reap': GeoPoint(13.3671, 103.8448),
    'rep': GeoPoint(13.4107, 103.8128),
    'sai': GeoPoint(13.2383, 104.2239),
    'phnom penh': GeoPoint(11.5564, 104.9282),
    'pnh': GeoPoint(11.5466, 104.8441),
    'bangkok': GeoPoint(13.7563, 100.5018),
    'grand palace': GeoPoint(13.7500, 100.4914),
    'wat arun': GeoPoint(13.7437, 100.4888),
    'wat pho': GeoPoint(13.7466, 100.4933),
    'sukhumvit': GeoPoint(13.7380, 100.5604),
    'silom': GeoPoint(13.7258, 100.5284),
    'siam': GeoPoint(13.7456, 100.5342),
    'chatuchak': GeoPoint(13.7999, 100.5505),
    'bkk': GeoPoint(13.6900, 100.7501),
    'dmk': GeoPoint(13.9126, 100.6067),
    'ayutthaya': GeoPoint(14.3532, 100.5684),
    'chiang mai': GeoPoint(18.7883, 98.9853),
    'cnx': GeoPoint(18.7668, 98.9626),
    'phuket': GeoPoint(7.8804, 98.3923),
    'patong': GeoPoint(7.8961, 98.2974),
    'kata': GeoPoint(7.8228, 98.2980),
    'hkt': GeoPoint(8.1132, 98.3169),
    'koh samui': GeoPoint(9.5120, 100.0136),
    'usm': GeoPoint(9.5478, 100.0623),
    'krabi': GeoPoint(8.0863, 98.9063),
    'singapore': GeoPoint(1.3521, 103.8198),
    'singapur': GeoPoint(1.3521, 103.8198),
    'marina bay': GeoPoint(1.2838, 103.8591),
    'orchard': GeoPoint(1.3048, 103.8318),
    'sin': GeoPoint(1.3644, 103.9915),
    'kuala lumpur': GeoPoint(3.1390, 101.6869),
    'kul': GeoPoint(2.7456, 101.7072),
    'bali': GeoPoint(-8.4095, 115.1889),
    'denpasar': GeoPoint(-8.6705, 115.2126),
    'dps': GeoPoint(-8.7482, 115.1672),
    'jakarta': GeoPoint(-6.2088, 106.8456),
    'cgk': GeoPoint(-6.1275, 106.6537),
    'manila': GeoPoint(14.5995, 120.9842),
    'mnl': GeoPoint(14.5086, 121.0194),

    // Europe
    'london': GeoPoint(51.5074, -0.1278),
    'lhr': GeoPoint(51.4700, -0.4543),
    'lgw': GeoPoint(51.1537, -0.1821),
    'paris': GeoPoint(48.8566, 2.3522),
    'cdg': GeoPoint(49.0097, 2.5479),
    'ory': GeoPoint(48.7262, 2.3652),
    'rome': GeoPoint(41.9028, 12.4964),
    'roma': GeoPoint(41.9028, 12.4964),
    'fco': GeoPoint(41.8003, 12.2389),
    'florence': GeoPoint(43.7696, 11.2558),
    'firenze': GeoPoint(43.7696, 11.2558),
    'flr': GeoPoint(43.8100, 11.2051),
    'venice': GeoPoint(45.4408, 12.3155),
    'vce': GeoPoint(45.5053, 12.3519),
    'milan': GeoPoint(45.4642, 9.1900),
    'mxp': GeoPoint(45.6301, 8.7231),
    'naples': GeoPoint(40.8518, 14.2681),
    'amalfi': GeoPoint(40.6340, 14.6027),
    'positano': GeoPoint(40.6281, 14.4850),
    'madrid': GeoPoint(40.4168, -3.7038),
    'mad': GeoPoint(40.4839, -3.5680),
    'barcelona': GeoPoint(41.3851, 2.1734),
    'bcn': GeoPoint(41.2974, 2.0833),
    'amsterdam': GeoPoint(52.3676, 4.9041),
    'ams': GeoPoint(52.3105, 4.7683),
    'berlin': GeoPoint(52.5200, 13.4050),
    'ber': GeoPoint(52.3667, 13.5033),
    'munich': GeoPoint(48.1351, 11.5820),
    'muc': GeoPoint(48.3537, 11.7860),
    'frankfurt': GeoPoint(50.1109, 8.6821),
    'fra': GeoPoint(50.0379, 8.5622),
    'vienna': GeoPoint(48.2082, 16.3738),
    'vie': GeoPoint(48.1103, 16.5697),
    'prague': GeoPoint(50.0755, 14.4378),
    'prg': GeoPoint(50.1008, 14.2600),
    'zurich': GeoPoint(47.3769, 8.5417),
    'zrh': GeoPoint(47.4582, 8.5555),
    'athens': GeoPoint(37.9838, 23.7275),
    'ath': GeoPoint(37.9364, 23.9445),
    'lisbon': GeoPoint(38.7223, -9.1393),
    'lis': GeoPoint(38.7756, -9.1354),

    // Middle East, Oceania, South America, Africa
    'dubai': GeoPoint(25.2048, 55.2708),
    'dxb': GeoPoint(25.2532, 55.3657),
    'doha': GeoPoint(25.2854, 51.5310),
    'doh': GeoPoint(25.2609, 51.5651),
    'sydney': GeoPoint(-33.8688, 151.2093),
    'syd': GeoPoint(-33.9399, 151.1753),
    'melbourne': GeoPoint(-37.8136, 144.9631),
    'mel': GeoPoint(-37.6690, 144.8410),
    'auckland': GeoPoint(-36.8485, 174.7633),
    'akl': GeoPoint(-37.0082, 174.7850),
    'cairo': GeoPoint(30.0444, 31.2357),
    'cai': GeoPoint(30.1219, 31.4056),
    'cape town': GeoPoint(-33.9249, 18.4241),
    'cpt': GeoPoint(-33.9715, 18.6021),
    'rio de janeiro': GeoPoint(-22.9068, -43.1729),
    'gig': GeoPoint(-22.8099, -43.2505),
    'buenos aires': GeoPoint(-34.6037, -58.3816),
    'eze': GeoPoint(-34.8222, -58.5358),
  };

  /// Resolves the geographic coordinates for a given city or airport name/code or address.
  static GeoPoint resolveCoordinates(String nameOrCode, {String? contextCountry}) {
    final clean = nameOrCode.toLowerCase().trim();

    // 0. Normalize address typos e.g. "sammish" -> "sammamish"
    final normalized = clean
        .replaceAll('sammish', 'sammamish')
        .replaceAll(RegExp(r'\b\d{5}(-\d{4})?\b'), '')
        .trim();

    // 1. Direct match
    if (_knownCoordinates.containsKey(clean)) {
      return _knownCoordinates[clean]!;
    }
    if (_knownCoordinates.containsKey(normalized)) {
      return _knownCoordinates[normalized]!;
    }

    // 2. Extract potential 3-letter IATA code in parentheses e.g. "SEA (Seattle)" or "SIN (Singapore Changi)"
    final iataMatch = RegExp(r'\b([A-Za-z]{3})\b').allMatches(nameOrCode);
    for (final m in iataMatch) {
      final code = m.group(1)!.toLowerCase();
      if (code == 'usa' || code == 'the' || code == 'and' || code == 'for') continue;
      if (_knownCoordinates.containsKey(code)) {
        return _knownCoordinates[code]!;
      }
    }

    // 3. Match against known places sorted by length descending so specific landmarks/streets
    // like "3942 west lake sammamish" or "west lake sammamish" match before "lake" or "seattle"
    final sortedKeys = _knownCoordinates.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final key in sortedKeys) {
      if (key.length >= 4) {
        if (clean.contains(key) || normalized.contains(key)) {
          return _knownCoordinates[key]!;
        }
      }
    }

    // 4. Split address by commas (e.g. "3942 West Lake Sammish Pkwy SE, Bellevue WA 98008, USA")
    // and check each comma segment
    final segments = clean.split(',');
    for (final seg in segments) {
      final segClean = seg
          .trim()
          .replaceAll('sammish', 'sammamish')
          .replaceAll(RegExp(r'\b(wa|ca|ny|fl|tx|il|or|co|nv)\b'), '')
          .trim();
      for (final key in sortedKeys) {
        if (key.length >= 4 && (segClean.contains(key) || key.contains(segClean))) {
          return _knownCoordinates[key]!;
        }
      }
    }

    // 5. Country/region fallback with deterministic offset based on string hash
    final hash = clean.codeUnits.fold<int>(0, (s, c) => s + c);
    final offsetLat = ((hash % 100) - 50) / 100.0 * 2.0; // +/- 1 deg
    final offsetLng = (((hash ~/ 100) % 100) - 50) / 100.0 * 2.0;

    final countryLower = (contextCountry ?? '').toLowerCase().trim();

    // If contextCountry is a known city (e.g. "Seattle", "Tokyo", "Bangkok"), anchor locally
    if (_knownCoordinates.containsKey(countryLower)) {
      final cityCoord = _knownCoordinates[countryLower]!;
      return GeoPoint(
        cityCoord.lat + (((hash % 50) - 25) / 1000.0),
        cityCoord.lng + ((((hash ~/ 50) % 50) - 25) / 1000.0),
      );
    }

    if (countryLower.contains('vietnam') || clean.contains('vietnam')) {
      return GeoPoint(16.0 + offsetLat, 107.0 + offsetLng);
    }
    if (countryLower.contains('japan') || clean.contains('japan')) {
      return GeoPoint(36.0 + offsetLat, 138.0 + offsetLng);
    }
    if (countryLower.contains('thailand') || clean.contains('thailand')) {
      return GeoPoint(14.0 + offsetLat, 100.5 + offsetLng);
    }
    if (countryLower.contains('cambodia') || clean.contains('cambodia')) {
      return GeoPoint(12.5 + offsetLat, 104.5 + offsetLng);
    }
    if (countryLower.contains('korea') || clean.contains('korea')) {
      return GeoPoint(36.5 + offsetLat, 127.5 + offsetLng);
    }
    if (countryLower.contains('italy') || clean.contains('italy') || clean.contains('italia')) {
      return GeoPoint(42.0 + offsetLat, 12.5 + offsetLng);
    }
    if (countryLower.contains('spain') || clean.contains('spain') || clean.contains('espana')) {
      return GeoPoint(40.0 + offsetLat, -3.5 + offsetLng);
    }
    if (countryLower.contains('france') || clean.contains('france')) {
      return GeoPoint(46.5 + offsetLat, 2.5 + offsetLng);
    }
    if (countryLower.contains('seattle') || clean.contains('seattle')) {
      return GeoPoint(47.6062 + offsetLat * 0.05, -122.3321 + offsetLng * 0.05);
    }
    if (countryLower.contains('united states') ||
        countryLower.contains('usa') ||
        countryLower.contains('america') ||
        clean.contains('usa') ||
        clean.contains('united states')) {
      // Default center of Continental US, NOT Seattle Arboretum
      return GeoPoint(39.8283 + offsetLat * 2.0, -98.5795 + offsetLng * 4.0);
    }

    // Default global coordinate spread
    return GeoPoint(20.0 + offsetLat, 100.0 + offsetLng);
  }

  /// Cleans an airport string like "SEA (Seattle)" or "ICN (Seoul Incheon)" into its primary city name.
  static String extractCityNameFromAirport(String airportStr) {
    final lower = airportStr.toLowerCase();

    // 1. Check full city names first
    if (lower.contains('seattle')) return 'Seattle';
    if (lower.contains('tokyo')) return 'Tokyo';
    if (lower.contains('singapore') || lower.contains('singapur')) return 'Singapore';
    if (lower.contains('hanoi')) return 'Hanoi';
    if (lower.contains('siem reap') || lower.contains('angkor')) return 'Siem Reap';
    if (lower.contains('bangkok')) return 'Bangkok';
    if (lower.contains('seoul') || lower.contains('incheon')) return 'Seoul';
    if (lower.contains('san francisco')) return 'San Francisco';
    if (lower.contains('los angeles')) return 'Los Angeles';
    if (lower.contains('new york')) return 'New York';
    if (lower.contains('kyoto')) return 'Kyoto';
    if (lower.contains('osaka')) return 'Osaka';
    if (lower.contains('rome')) return 'Rome';
    if (lower.contains('florence')) return 'Florence';
    if (lower.contains('positano') || lower.contains('amalfi')) return 'Amalfi Coast';
    if (lower.contains('paris')) return 'Paris';
    if (lower.contains('london')) return 'London';

    // 2. Tokenized IATA 3-letter code matching (using word boundaries \b to avoid substrings like 'changi' containing 'han')
    final iataMatches = RegExp(r'\b([A-Za-z]{3})\b').allMatches(airportStr);
    for (final m in iataMatches) {
      final code = m.group(1)!.toUpperCase();
      switch (code) {
        case 'SEA': return 'Seattle';
        case 'HND':
        case 'NRT': return 'Tokyo';
        case 'SIN': return 'Singapore';
        case 'HAN': return 'Hanoi';
        case 'REP':
        case 'SAI': return 'Siem Reap';
        case 'BKK':
        case 'DMK': return 'Bangkok';
        case 'ICN':
        case 'GMP': return 'Seoul';
        case 'SFO': return 'San Francisco';
        case 'LAX': return 'Los Angeles';
        case 'JFK':
        case 'EWR':
        case 'LGA': return 'New York';
        case 'KIX':
        case 'ITM': return 'Osaka';
        case 'FCO':
        case 'CIA': return 'Rome';
        case 'FLR': return 'Florence';
        case 'CDG':
        case 'ORY': return 'Paris';
        case 'LHR':
        case 'LGW': return 'London';
      }
    }

    // 3. Parentheses contents e.g. "HAN (Hanoi)"
    final parenMatch = RegExp(r'\(([^)]+)\)').firstMatch(airportStr);
    if (parenMatch != null) {
      final inner = parenMatch.group(1)!.trim();
      final words = inner.split(' ');
      return words.first;
    }

    return airportStr.trim();
  }

  /// Extracts the full chronological trip route, including all cities visited in sequence
  /// and the connecting legs (flights or ground transit) between them.
  static TripMapRoute extractRoute({
    required Trip trip,
    required List<Stay> stays,
    required List<Flight> flights,
    required Map<DateTime, List<Activity>> activitiesByDay,
  }) {
    // 1. Sort flights and stays chronologically
    final sortedFlights = List<Flight>.from(flights)
      ..sort((a, b) => a.departureTime.compareTo(b.departureTime));

    final sortedStays = List<Stay>.from(
      stays.where((s) => s.type != StayType.overnightFlight),
    )..sort((a, b) => a.checkInDate.compareTo(b.checkInDate));

    // Flatten all activities
    final allActivities = <Activity>[];
    activitiesByDay.values.forEach(allActivities.addAll);

    // 2. Identify the origin city (e.g. Seattle)
    String? originCity;
    Flight? firstOutboundFlight;
    if (sortedFlights.isNotEmpty) {
      firstOutboundFlight = sortedFlights.first;
      originCity = extractCityNameFromAirport(firstOutboundFlight.departureAirport);
    }

    // 3. Collect chronological sequence of cities visited
    // Each stop represents a city visit
    final rawStops = <_CityVisit>[];

    // Add origin if first flight leaves from an origin
    if (originCity != null && originCity.isNotEmpty) {
      rawStops.add(_CityVisit(
        cityName: originCity,
        date: firstOutboundFlight!.departureTime,
        isOrigin: true,
      ));
    }

    // Walk through sorted flights and stays
    final allEvents = <_TimelineEvent>[];
    for (final f in sortedFlights) {
      allEvents.add(_TimelineEvent(
        time: f.departureTime,
        type: _EventType.flightDeparture,
        flight: f,
      ));
      allEvents.add(_TimelineEvent(
        time: f.arrivalTime,
        type: _EventType.flightArrival,
        flight: f,
      ));
    }
    for (final s in sortedStays) {
      final city = CityColorHelper.extractCityForStay(s);
      allEvents.add(_TimelineEvent(
        time: s.checkInDate,
        type: _EventType.stayCheckIn,
        stay: s,
        cityName: city,
      ));
    }

    allEvents.sort((a, b) => a.time.compareTo(b.time));

    String? currentCity = originCity;
    for (final event in allEvents) {
      if (event.type == _EventType.flightArrival && event.flight != null) {
        final arrCity = extractCityNameFromAirport(event.flight!.arrivalAirport);
        if (arrCity != currentCity) {
          rawStops.add(_CityVisit(
            cityName: arrCity,
            date: event.time,
            arrivingFlight: event.flight,
          ));
          currentCity = arrCity;
        }
      } else if (event.type == _EventType.stayCheckIn && event.stay != null) {
        final stayCity = event.cityName ?? CityColorHelper.extractCityForStay(event.stay!);
        if (stayCity != null && stayCity.isNotEmpty && stayCity != currentCity) {
          rawStops.add(_CityVisit(
            cityName: stayCity,
            date: event.time,
            stay: event.stay,
          ));
          currentCity = stayCity;
        }
      }
    }

    // If no flights, just use stays
    if (rawStops.isEmpty && sortedStays.isNotEmpty) {
      for (final s in sortedStays) {
        final city = CityColorHelper.extractCityForStay(s) ?? s.name;
        if (city.isNotEmpty && (rawStops.isEmpty || rawStops.last.cityName != city)) {
          rawStops.add(_CityVisit(
            cityName: city,
            date: s.checkInDate,
            stay: s,
          ));
        }
      }
    }

    // Fallback: If still empty, check dayLocations or trip destination
    if (rawStops.isEmpty) {
      final destParts = trip.destination.split(',');
      final fallbackCity = destParts.first.trim();
      rawStops.add(_CityVisit(
        cityName: fallbackCity,
        date: trip.startDate,
      ));
    }

    // 4. Consolidate and number cities with sequence flow & callout offsets
    final cityVisitCounts = <String, int>{};
    for (final s in rawStops) {
      final key = s.cityName.toLowerCase();
      cityVisitCounts[key] = (cityVisitCounts[key] ?? 0) + 1;
    }

    final cityVisitIndices = <String, int>{};
    final cityNodes = <TripMapCityNode>[];
    int seqNum = 1;

    for (int i = 0; i < rawStops.length; i++) {
      final stop = rawStops[i];
      final cName = stop.cityName;
      final cLower = cName.toLowerCase();
      final visitIndex = cityVisitIndices[cLower] ?? 0;
      cityVisitIndices[cLower] = visitIndex + 1;
      final totalVisits = cityVisitCounts[cLower] ?? 1;

      // Find all stays in this city
      final cityStays = sortedStays.where((s) {
        final sCity = CityColorHelper.extractCityForStay(s);
        if (sCity == null) return false;
        return sCity.toLowerCase() == cName.toLowerCase() ||
            cName.toLowerCase().contains(sCity.toLowerCase()) ||
            sCity.toLowerCase().contains(cName.toLowerCase());
      }).toList();

      List<Stay> relevantStays;
      if (stop.stay != null) {
        relevantStays = [stop.stay!];
      } else {
        final matching = cityStays.where((s) =>
            s.checkInDate.isAfter(stop.date.subtract(const Duration(hours: 18))) &&
            s.checkInDate.isBefore(stop.date.add(const Duration(days: 3)))).toList();
        relevantStays = matching.isNotEmpty ? matching : cityStays;
      }

      int nights = 0;
      for (final s in relevantStays) {
        nights += s.nights > 0 ? s.nights : 1;
      }

      // Find activities in this city
      final cityActivities = allActivities.where((a) {
        final loc = a.location?.toLowerCase() ?? '';
        final title = a.title.toLowerCase();
        return loc.contains(cName.toLowerCase()) || title.contains(cName.toLowerCase());
      }).toList();

      final coords = resolveCoordinates(cName, contextCountry: trip.destination);

      // Compute Callout Offset to prevent overlaps if same city has multiple sequence numbers
      Offset calloutOffset = Offset.zero;
      if (totalVisits > 1) {
        if (cLower == 'tokyo') {
          // Tokyo: Stop 2 offset NW (-65, -55), Stop 4 offset SE (+65, +48)
          calloutOffset = (visitIndex == 0) ? const Offset(-65, -55) : const Offset(65, 48);
        } else if (cLower == 'hanoi') {
          // Hanoi: Stop 5 offset NW (-65, -48), Stop 8 offset W/SW (-65, +35)
          calloutOffset = (visitIndex == 0) ? const Offset(-65, -48) : const Offset(-65, 35);
        } else if (cLower == 'bangkok') {
          // Bangkok: Stop 10 offset SW (-60, +45), Stop 12 offset SE (+60, +45)
          calloutOffset = (visitIndex == 0) ? const Offset(-60, 45) : const Offset(60, 45);
        } else if (cLower == 'seattle') {
          // Seattle: Stop 1 offset NW (-55, -45), Stop 15 offset SW (-55, +45)
          calloutOffset = (visitIndex == 0) ? const Offset(-55, -45) : const Offset(-55, 45);
        } else {
          final angle = -math.pi * 0.75 + (visitIndex * 2 * math.pi / totalVisits);
          calloutOffset = Offset(math.cos(angle) * 65.0, math.sin(angle) * 55.0);
        }
      }

      cityNodes.add(TripMapCityNode(
        sequenceNumber: seqNum++,
        cityName: cName,
        countryName: trip.destination,
        coordinates: coords,
        arrivalDate: stop.date,
        totalNights: nights,
        stays: relevantStays,
        activities: cityActivities,
        isOriginOrReturn: stop.isOrigin,
        visitIndex: visitIndex,
        totalVisitsToThisCity: totalVisits,
        calloutOffset: calloutOffset,
      ));
    }

    // 5. Build connecting legs between consecutive cities in chronological order
    final legs = <TripMapConnectionLeg>[];
    final usedFlightIds = <String>{};

    for (int i = 0; i < cityNodes.length - 1; i++) {
      final from = cityNodes[i];
      final to = cityNodes[i + 1];

      // Find if there is a flight between from and to
      Flight? matchedFlight;
      for (final f in sortedFlights) {
        if (usedFlightIds.contains(f.id)) continue;
        final depCity = extractCityNameFromAirport(f.departureAirport);
        final arrCity = extractCityNameFromAirport(f.arrivalAirport);
        if ((depCity.toLowerCase() == from.cityName.toLowerCase() ||
                from.cityName.toLowerCase().contains(depCity.toLowerCase())) &&
            (arrCity.toLowerCase() == to.cityName.toLowerCase() ||
                to.cityName.toLowerCase().contains(arrCity.toLowerCase()))) {
          matchedFlight = f;
          usedFlightIds.add(f.id);
          break;
        }
      }

      // Moniker text
      String moniker;
      bool isFlight = false;
      if (matchedFlight != null) {
        isFlight = true;
        final fn = matchedFlight.flightNumber.trim();
        final al = matchedFlight.airline.trim();
        moniker = fn.isNotEmpty ? fn : al;
      } else {
        moniker = 'Transfer';
      }

      legs.add(TripMapConnectionLeg(
        sequenceIndex: i + 1,
        fromCity: from,
        toCity: to,
        flight: matchedFlight,
        moniker: moniker,
        isFlight: isFlight,
        departureTime: matchedFlight?.departureTime,
        arrivalTime: matchedFlight?.arrivalTime,
      ));
    }

    // Check if the final flight returns to the origin city
    if (cityNodes.length >= 2 && sortedFlights.isNotEmpty) {
      final lastFlight = sortedFlights.last;
      if (!legs.any((l) => l.flight?.id == lastFlight.id)) {
        final returnCity = extractCityNameFromAirport(lastFlight.arrivalAirport);
        final origin = cityNodes.first;
        final lastCity = cityNodes.last;

        if (returnCity.toLowerCase() == origin.cityName.toLowerCase() &&
            lastCity.cityName.toLowerCase() != origin.cityName.toLowerCase()) {
          final fn = lastFlight.flightNumber.trim();
          final moniker = fn.isNotEmpty ? fn : lastFlight.airline;
          legs.add(TripMapConnectionLeg(
            sequenceIndex: legs.length + 1,
            fromCity: lastCity,
            toCity: origin,
            flight: lastFlight,
            moniker: moniker,
            isFlight: true,
            departureTime: lastFlight.departureTime,
            arrivalTime: lastFlight.arrivalTime,
          ));
        }
      }
    }

    // 6. Compute bounding box and determine if route crosses Pacific
    double minLat = 90.0, maxLat = -90.0;
    double minLng = 180.0, maxLng = -180.0;
    bool hasEastAsia = false;
    bool hasNorthAmerica = false;

    for (final node in cityNodes) {
      final lat = node.coordinates.lat;
      final lng = node.coordinates.lng;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;

      if (lng > 90.0 && lng < 155.0) hasEastAsia = true;
      if (lng < -60.0 && lng > -170.0) hasNorthAmerica = true;
    }

    final crossesPacific = hasEastAsia && hasNorthAmerica;

    return TripMapRoute(
      cities: cityNodes,
      legs: legs,
      minLat: minLat.isFinite ? minLat : 10.0,
      maxLat: maxLat.isFinite ? maxLat : 45.0,
      minLng: minLng.isFinite ? minLng : 95.0,
      maxLng: maxLng.isFinite ? maxLng : 145.0,
      crossesPacific: crossesPacific,
    );
  }
}

enum _EventType { flightDeparture, flightArrival, stayCheckIn }

class _TimelineEvent {
  final DateTime time;
  final _EventType type;
  final Flight? flight;
  final Stay? stay;
  final String? cityName;

  _TimelineEvent({
    required this.time,
    required this.type,
    this.flight,
    this.stay,
    this.cityName,
  });
}

class _CityVisit {
  final String cityName;
  final DateTime date;
  final Stay? stay;
  final Flight? arrivingFlight;
  final bool isOrigin;

  _CityVisit({
    required this.cityName,
    required this.date,
    this.stay,
    this.arrivingFlight,
    this.isOrigin = false,
  });
}
