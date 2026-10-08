/// Helper to calculate flight duration accounting for airport timezones and DST.
class AirportTimezoneHelper {
  /// Calculates elapsed flight duration considering departure and arrival timezones.
  static Duration calculateDuration({
    required DateTime departureTime,
    required String departureAirport,
    required DateTime arrivalTime,
    required String arrivalAirport,
  }) {
    final depOffset = getUtcOffset(departureAirport, departureTime);
    final arrOffset = getUtcOffset(arrivalAirport, arrivalTime);

    if (depOffset != null && arrOffset != null) {
      final depUtc = departureTime.subtract(depOffset);
      final arrUtc = arrivalTime.subtract(arrOffset);
      final diff = arrUtc.difference(depUtc);

      if (diff.isNegative) {
        // Handle cases where arrival time wrapped across midnight without date increment
        return diff + const Duration(hours: 24);
      }
      return diff;
    }

    final naive = arrivalTime.difference(departureTime);
    if (naive.isNegative) {
      return naive + const Duration(hours: 24);
    }
    return naive;
  }

  /// Extracts the 3-letter IATA code from airport text, or matches known city names.
  static String? extractIataCode(String airportString) {
    if (airportString.trim().isEmpty) return null;

    final trimmed = airportString.trim().toUpperCase();

    // Check for parenthesized 3-letter code e.g. "Seattle (SEA)"
    final parenMatch = RegExp(r'\(([A-Z]{3})\)').firstMatch(trimmed);
    if (parenMatch != null) {
      return parenMatch.group(1);
    }

    // Check for leading 3-letter code e.g. "SEA (Seattle)" or "SEA"
    final leadMatch = RegExp(r'^([A-Z]{3})\b').firstMatch(trimmed);
    if (leadMatch != null) {
      return leadMatch.group(1);
    }

    // Check for any 3-letter word in uppercase
    final anyMatch = RegExp(r'\b([A-Z]{3})\b').firstMatch(trimmed);
    if (anyMatch != null) {
      return anyMatch.group(1);
    }

    // Fallback: check city names
    final lower = airportString.toLowerCase();
    for (final entry in _cityToIata.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Resolves the UTC offset [Duration] for an airport at a given local [date].
  static Duration? getUtcOffset(String airport, DateTime date) {
    final iata = extractIataCode(airport);
    if (iata == null) return null;

    final info = _airportData[iata];
    if (info == null) return null;

    final baseHours = info.baseOffsetHours;
    final baseMinutes = info.baseOffsetMinutes;

    int dstAdjustmentHours = 0;
    if (info.dstRule == _DstRule.us) {
      if (_isUsDst(date)) {
        dstAdjustmentHours = 1;
      }
    } else if (info.dstRule == _DstRule.eu) {
      if (_isEuDst(date)) {
        dstAdjustmentHours = 1;
      }
    } else if (info.dstRule == _DstRule.au) {
      if (_isAuDst(date)) {
        dstAdjustmentHours = 1;
      }
    } else if (info.dstRule == _DstRule.nz) {
      if (_isNzDst(date)) {
        dstAdjustmentHours = 1;
      }
    }

    final totalMinutes = ((baseHours + dstAdjustmentHours) * 60) +
        (baseHours < 0 ? -baseMinutes : baseMinutes);

    return Duration(minutes: totalMinutes);
  }

  /// Checks if [date] falls in US/Canada Daylight Saving Time:
  /// Starts 2nd Sunday in March at 2:00 AM, ends 1st Sunday in November at 2:00 AM.
  static bool _isUsDst(DateTime date) {
    final year = date.year;
    final secondSunMarch = _findNthSunday(year, 3, 2);
    final dstStart = DateTime(year, 3, secondSunMarch, 2, 0);

    final firstSunNov = _findNthSunday(year, 11, 1);
    final dstEnd = DateTime(year, 11, firstSunNov, 2, 0);

    return date.isAfter(dstStart) && date.isBefore(dstEnd);
  }

  /// Checks if [date] falls in European Daylight Saving Time (CEST/BST):
  /// Starts last Sunday in March at 1:00 AM UTC, ends last Sunday in October at 1:00 AM UTC.
  static bool _isEuDst(DateTime date) {
    final year = date.year;
    final lastSunMarch = _findLastSunday(year, 3);
    final dstStart = DateTime(year, 3, lastSunMarch, 2, 0);

    final lastSunOct = _findLastSunday(year, 10);
    final dstEnd = DateTime(year, 10, lastSunOct, 2, 0);

    return date.isAfter(dstStart) && date.isBefore(dstEnd);
  }

  /// Checks Australian DST (NSW, Victoria, Tasmania):
  /// Starts 1st Sunday in October at 2:00 AM, ends 1st Sunday in April at 2:00 AM.
  static bool _isAuDst(DateTime date) {
    final year = date.year;
    final firstSunOct = _findNthSunday(year, 10, 1);
    final dstStart = DateTime(year, 10, firstSunOct, 2, 0);

    final firstSunApr = _findNthSunday(year, 4, 1);
    final dstEnd = DateTime(year, 4, firstSunApr, 2, 0);

    return date.isAfter(dstStart) || date.isBefore(dstEnd);
  }

  /// Checks New Zealand DST:
  /// Starts last Sunday in September, ends 1st Sunday in April.
  static bool _isNzDst(DateTime date) {
    final year = date.year;
    final lastSunSep = _findLastSunday(year, 9);
    final dstStart = DateTime(year, 9, lastSunSep, 2, 0);

    final firstSunApr = _findNthSunday(year, 4, 1);
    final dstEnd = DateTime(year, 4, firstSunApr, 2, 0);

    return date.isAfter(dstStart) || date.isBefore(dstEnd);
  }

  static int _findNthSunday(int year, int month, int n) {
    int count = 0;
    for (int day = 1; day <= 31; day++) {
      final d = DateTime(year, month, day);
      if (d.month != month) break;
      if (d.weekday == DateTime.sunday) {
        count++;
        if (count == n) return day;
      }
    }
    return 1;
  }

  static int _findLastSunday(int year, int month) {
    int last = 1;
    for (int day = 1; day <= 31; day++) {
      final d = DateTime(year, month, day);
      if (d.month != month) break;
      if (d.weekday == DateTime.sunday) {
        last = day;
      }
    }
    return last;
  }

  static final Map<String, String> _cityToIata = {
    'seattle': 'SEA',
    'tokyo': 'HND',
    'haneda': 'HND',
    'narita': 'NRT',
    'hanoi': 'HAN',
    'siem reap': 'SAI',
    'bangkok': 'BKK',
    'singapore': 'SIN',
    'seoul': 'ICN',
    'incheon': 'ICN',
    'san francisco': 'SFO',
    'los angeles': 'LAX',
    'new york': 'JFK',
    'chicago': 'ORD',
    'london': 'LHR',
    'paris': 'CDG',
    'frankfurt': 'FRA',
    'amsterdam': 'AMS',
    'rome': 'FCO',
    'madrid': 'MAD',
    'barcelona': 'BCN',
    'dubai': 'DXB',
    'doha': 'DOH',
    'hong kong': 'HKG',
    'taipei': 'TPE',
    'osaka': 'KIX',
    'kyoto': 'KIX',
    'chiang mai': 'CNX',
    'phuket': 'HKT',
    'ho chi minh': 'SGN',
    'saigon': 'SGN',
    'da nang': 'DAD',
    'kuala lumpur': 'KUL',
    'bali': 'DPS',
    'denpasar': 'DPS',
    'jakarta': 'CGK',
    'sydney': 'SYD',
    'melbourne': 'MEL',
    'auckland': 'AKL',
    'honolulu': 'HNL',
  };

  static final Map<String, _AirportInfo> _airportData = {
    // US & Canada - Pacific (UTC-8, DST UTC-7)
    'SEA': const _AirportInfo(-8, dstRule: _DstRule.us),
    'SFO': const _AirportInfo(-8, dstRule: _DstRule.us),
    'LAX': const _AirportInfo(-8, dstRule: _DstRule.us),
    'SAN': const _AirportInfo(-8, dstRule: _DstRule.us),
    'PDX': const _AirportInfo(-8, dstRule: _DstRule.us),
    'LAS': const _AirportInfo(-8, dstRule: _DstRule.us),
    'OAK': const _AirportInfo(-8, dstRule: _DstRule.us),
    'SJC': const _AirportInfo(-8, dstRule: _DstRule.us),
    'SMF': const _AirportInfo(-8, dstRule: _DstRule.us),
    'YVR': const _AirportInfo(-8, dstRule: _DstRule.us),

    // US & Canada - Mountain (UTC-7, DST UTC-6, except PHX)
    'DEN': const _AirportInfo(-7, dstRule: _DstRule.us),
    'SLC': const _AirportInfo(-7, dstRule: _DstRule.us),
    'ABQ': const _AirportInfo(-7, dstRule: _DstRule.us),
    'BOI': const _AirportInfo(-7, dstRule: _DstRule.us),
    'YYC': const _AirportInfo(-7, dstRule: _DstRule.us),
    'YEG': const _AirportInfo(-7, dstRule: _DstRule.us),
    'PHX': const _AirportInfo(-7, dstRule: _DstRule.none), // Arizona no DST

    // US & Canada - Central (UTC-6, DST UTC-5)
    'ORD': const _AirportInfo(-6, dstRule: _DstRule.us),
    'MDW': const _AirportInfo(-6, dstRule: _DstRule.us),
    'DFW': const _AirportInfo(-6, dstRule: _DstRule.us),
    'IAH': const _AirportInfo(-6, dstRule: _DstRule.us),
    'HOU': const _AirportInfo(-6, dstRule: _DstRule.us),
    'MSP': const _AirportInfo(-6, dstRule: _DstRule.us),
    'AUS': const _AirportInfo(-6, dstRule: _DstRule.us),
    'SAT': const _AirportInfo(-6, dstRule: _DstRule.us),
    'STL': const _AirportInfo(-6, dstRule: _DstRule.us),
    'MCI': const _AirportInfo(-6, dstRule: _DstRule.us),
    'BNA': const _AirportInfo(-6, dstRule: _DstRule.us),
    'MEM': const _AirportInfo(-6, dstRule: _DstRule.us),
    'MSY': const _AirportInfo(-6, dstRule: _DstRule.us),
    'YWG': const _AirportInfo(-6, dstRule: _DstRule.us),

    // US & Canada - Eastern (UTC-5, DST UTC-4)
    'JFK': const _AirportInfo(-5, dstRule: _DstRule.us),
    'EWR': const _AirportInfo(-5, dstRule: _DstRule.us),
    'LGA': const _AirportInfo(-5, dstRule: _DstRule.us),
    'BOS': const _AirportInfo(-5, dstRule: _DstRule.us),
    'ATL': const _AirportInfo(-5, dstRule: _DstRule.us),
    'MIA': const _AirportInfo(-5, dstRule: _DstRule.us),
    'MCO': const _AirportInfo(-5, dstRule: _DstRule.us),
    'TPA': const _AirportInfo(-5, dstRule: _DstRule.us),
    'FLL': const _AirportInfo(-5, dstRule: _DstRule.us),
    'IAD': const _AirportInfo(-5, dstRule: _DstRule.us),
    'DCA': const _AirportInfo(-5, dstRule: _DstRule.us),
    'BWI': const _AirportInfo(-5, dstRule: _DstRule.us),
    'PHL': const _AirportInfo(-5, dstRule: _DstRule.us),
    'CLT': const _AirportInfo(-5, dstRule: _DstRule.us),
    'RDU': const _AirportInfo(-5, dstRule: _DstRule.us),
    'DTW': const _AirportInfo(-5, dstRule: _DstRule.us),
    'CLE': const _AirportInfo(-5, dstRule: _DstRule.us),
    'PIT': const _AirportInfo(-5, dstRule: _DstRule.us),
    'IND': const _AirportInfo(-5, dstRule: _DstRule.us),
    'YYZ': const _AirportInfo(-5, dstRule: _DstRule.us),
    'YUL': const _AirportInfo(-5, dstRule: _DstRule.us),
    'YOW': const _AirportInfo(-5, dstRule: _DstRule.us),

    // Alaska & Hawaii
    'ANC': const _AirportInfo(-9, dstRule: _DstRule.us),
    'FAI': const _AirportInfo(-9, dstRule: _DstRule.us),
    'HNL': const _AirportInfo(-10, dstRule: _DstRule.none),
    'OGG': const _AirportInfo(-10, dstRule: _DstRule.none),
    'KOA': const _AirportInfo(-10, dstRule: _DstRule.none),
    'LIH': const _AirportInfo(-10, dstRule: _DstRule.none),

    // Japan (UTC+9, no DST)
    'HND': const _AirportInfo(9),
    'NRT': const _AirportInfo(9),
    'KIX': const _AirportInfo(9),
    'ITM': const _AirportInfo(9),
    'FUK': const _AirportInfo(9),
    'CTS': const _AirportInfo(9),
    'OKA': const _AirportInfo(9),
    'NGO': const _AirportInfo(9),

    // South Korea (UTC+9, no DST)
    'ICN': const _AirportInfo(9),
    'GMP': const _AirportInfo(9),
    'PUS': const _AirportInfo(9),
    'CJU': const _AirportInfo(9),

    // Vietnam (UTC+7, no DST)
    'HAN': const _AirportInfo(7),
    'SGN': const _AirportInfo(7),
    'DAD': const _AirportInfo(7),
    'CXR': const _AirportInfo(7),
    'PQC': const _AirportInfo(7),
    'HPH': const _AirportInfo(7),

    // Cambodia (UTC+7, no DST)
    'SAI': const _AirportInfo(7),
    'REP': const _AirportInfo(7),
    'PNH': const _AirportInfo(7),
    'KOS': const _AirportInfo(7),

    // Thailand (UTC+7, no DST)
    'BKK': const _AirportInfo(7),
    'DMK': const _AirportInfo(7),
    'HKT': const _AirportInfo(7),
    'CNX': const _AirportInfo(7),
    'KBV': const _AirportInfo(7),
    'USM': const _AirportInfo(7),
    'CEI': const _AirportInfo(7),
    'UTP': const _AirportInfo(7),

    // Singapore (UTC+8, no DST)
    'SIN': const _AirportInfo(8),
    'XSP': const _AirportInfo(8),

    // Malaysia (UTC+8, no DST)
    'KUL': const _AirportInfo(8),
    'PEN': const _AirportInfo(8),
    'BKI': const _AirportInfo(8),
    'KCH': const _AirportInfo(8),
    'LGK': const _AirportInfo(8),

    // Indonesia (WIB UTC+7, WITA UTC+8, WIT UTC+9)
    'CGK': const _AirportInfo(7),
    'SUB': const _AirportInfo(7),
    'JOG': const _AirportInfo(7),
    'DPS': const _AirportInfo(8), // Bali is WITA
    'LOP': const _AirportInfo(8),
    'UPG': const _AirportInfo(8),

    // China, Hong Kong, Taiwan (UTC+8, no DST)
    'PEK': const _AirportInfo(8),
    'PKX': const _AirportInfo(8),
    'PVG': const _AirportInfo(8),
    'SHA': const _AirportInfo(8),
    'CAN': const _AirportInfo(8),
    'SZX': const _AirportInfo(8),
    'CTU': const _AirportInfo(8),
    'TFU': const _AirportInfo(8),
    'CKG': const _AirportInfo(8),
    'XIY': const _AirportInfo(8),
    'KMG': const _AirportInfo(8),
    'HGH': const _AirportInfo(8),
    'HKG': const _AirportInfo(8),
    'MFM': const _AirportInfo(8),
    'TPE': const _AirportInfo(8),
    'TSA': const _AirportInfo(8),
    'KHH': const _AirportInfo(8),

    // Philippines (UTC+8, no DST)
    'MNL': const _AirportInfo(8),
    'CEB': const _AirportInfo(8),
    'CRK': const _AirportInfo(8),

    // India (UTC+5:30, no DST)
    'DEL': const _AirportInfo(5, baseOffsetMinutes: 30),
    'BOM': const _AirportInfo(5, baseOffsetMinutes: 30),
    'BLR': const _AirportInfo(5, baseOffsetMinutes: 30),
    'MAA': const _AirportInfo(5, baseOffsetMinutes: 30),
    'CCU': const _AirportInfo(5, baseOffsetMinutes: 30),
    'HYD': const _AirportInfo(5, baseOffsetMinutes: 30),

    // Middle East
    'DXB': const _AirportInfo(4),
    'AUH': const _AirportInfo(4),
    'SHJ': const _AirportInfo(4),
    'DOH': const _AirportInfo(3),
    'RUH': const _AirportInfo(3),
    'JED': const _AirportInfo(3),
    'DMM': const _AirportInfo(3),
    'KWI': const _AirportInfo(3),
    'BAH': const _AirportInfo(3),
    'MCT': const _AirportInfo(4),
    'TLV': const _AirportInfo(2, dstRule: _DstRule.eu),

    // UK & Ireland (UTC+0, DST UTC+1)
    'LHR': const _AirportInfo(0, dstRule: _DstRule.eu),
    'LGW': const _AirportInfo(0, dstRule: _DstRule.eu),
    'STN': const _AirportInfo(0, dstRule: _DstRule.eu),
    'LTN': const _AirportInfo(0, dstRule: _DstRule.eu),
    'MAN': const _AirportInfo(0, dstRule: _DstRule.eu),
    'EDI': const _AirportInfo(0, dstRule: _DstRule.eu),
    'BHX': const _AirportInfo(0, dstRule: _DstRule.eu),
    'DUB': const _AirportInfo(0, dstRule: _DstRule.eu),
    'LIS': const _AirportInfo(0, dstRule: _DstRule.eu),
    'OPO': const _AirportInfo(0, dstRule: _DstRule.eu),

    // Western / Central Europe (UTC+1, DST UTC+2)
    'CDG': const _AirportInfo(1, dstRule: _DstRule.eu),
    'ORY': const _AirportInfo(1, dstRule: _DstRule.eu),
    'FRA': const _AirportInfo(1, dstRule: _DstRule.eu),
    'MUC': const _AirportInfo(1, dstRule: _DstRule.eu),
    'BER': const _AirportInfo(1, dstRule: _DstRule.eu),
    'AMS': const _AirportInfo(1, dstRule: _DstRule.eu),
    'BRU': const _AirportInfo(1, dstRule: _DstRule.eu),
    'ZRH': const _AirportInfo(1, dstRule: _DstRule.eu),
    'GVA': const _AirportInfo(1, dstRule: _DstRule.eu),
    'VIE': const _AirportInfo(1, dstRule: _DstRule.eu),
    'MAD': const _AirportInfo(1, dstRule: _DstRule.eu),
    'BCN': const _AirportInfo(1, dstRule: _DstRule.eu),
    'FCO': const _AirportInfo(1, dstRule: _DstRule.eu),
    'MXP': const _AirportInfo(1, dstRule: _DstRule.eu),
    'LIN': const _AirportInfo(1, dstRule: _DstRule.eu),
    'VCE': const _AirportInfo(1, dstRule: _DstRule.eu),
    'NAP': const _AirportInfo(1, dstRule: _DstRule.eu),
    'CPH': const _AirportInfo(1, dstRule: _DstRule.eu),
    'ARN': const _AirportInfo(1, dstRule: _DstRule.eu),
    'OSL': const _AirportInfo(1, dstRule: _DstRule.eu),
    'PRG': const _AirportInfo(1, dstRule: _DstRule.eu),
    'WAW': const _AirportInfo(1, dstRule: _DstRule.eu),
    'BUD': const _AirportInfo(1, dstRule: _DstRule.eu),

    // Eastern Europe & Turkey
    'ATH': const _AirportInfo(2, dstRule: _DstRule.eu),
    'HEL': const _AirportInfo(2, dstRule: _DstRule.eu),
    'OTP': const _AirportInfo(2, dstRule: _DstRule.eu),
    'IST': const _AirportInfo(3), // Turkey UTC+3 permanent
    'SAW': const _AirportInfo(3),

    // Australia & NZ
    'SYD': const _AirportInfo(10, dstRule: _DstRule.au),
    'MEL': const _AirportInfo(10, dstRule: _DstRule.au),
    'BNE': const _AirportInfo(10, dstRule: _DstRule.none), // QLD no DST
    'ADL': const _AirportInfo(9, baseOffsetMinutes: 30, dstRule: _DstRule.au),
    'PER': const _AirportInfo(8, dstRule: _DstRule.none), // WA no DST
    'AKL': const _AirportInfo(12, dstRule: _DstRule.nz),
    'CHC': const _AirportInfo(12, dstRule: _DstRule.nz),
    'WLG': const _AirportInfo(12, dstRule: _DstRule.nz),

    // Latin America
    'MEX': const _AirportInfo(-6),
    'CUN': const _AirportInfo(-5),
    'GDL': const _AirportInfo(-6),
    'BOG': const _AirportInfo(-5),
    'MDE': const _AirportInfo(-5),
    'LIM': const _AirportInfo(-5),
    'SCL': const _AirportInfo(-4),
    'EZE': const _AirportInfo(-3),
    'AEP': const _AirportInfo(-3),
    'GRU': const _AirportInfo(-3),
    'GIG': const _AirportInfo(-3),
    'PTY': const _AirportInfo(-5),
    'SJO': const _AirportInfo(-6),
  };
}

enum _DstRule { none, us, eu, au, nz }

class _AirportInfo {
  final int baseOffsetHours;
  final int baseOffsetMinutes;
  final _DstRule dstRule;

  const _AirportInfo(
    this.baseOffsetHours, {
    this.baseOffsetMinutes = 0,
    this.dstRule = _DstRule.none,
  });
}
