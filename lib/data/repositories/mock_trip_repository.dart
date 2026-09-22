import 'dart:async';
import '../../models/models.dart';
import 'trip_repository.dart';

class MockTripRepository implements TripRepository {
  final List<Trip> _trips = [];
  final Map<String, List<Stay>> _stays = {};
  final Map<String, List<Activity>> _activities = {};
  final Map<String, List<Flight>> _flights = {};

  final StreamController<List<Trip>> _tripsController =
      StreamController<List<Trip>>.broadcast();
  final Map<String, StreamController<List<Stay>>> _staysControllers = {};
  final Map<String, StreamController<List<Activity>>> _activitiesControllers = {};
  final Map<String, StreamController<List<Flight>>> _flightsControllers = {};

  MockTripRepository() {
    _seedInitialData();
  }

  void _seedInitialData() {
    final now = DateTime.now();
    final day1 = DateTime(now.year, now.month, now.day + 15);
    final day2 = day1.add(const Duration(days: 1));
    final day3 = day1.add(const Duration(days: 2));
    final day4 = day1.add(const Duration(days: 3));
    final day5 = day1.add(const Duration(days: 4));

    final trip1 = Trip(
      id: 'trip_japan_2026',
      title: 'Japan Odyssey: Tokyo & Kyoto',
      destination: 'Tokyo & Kyoto, Japan',
      startDate: day1,
      endDate: day5,
      coverImageUrl:
          'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?auto=format&fit=crop&w=1200&q=80',
      ownerId: 'user_current',
      inviteCode: 'TYO-8821',
      defaultInviteRole: MemberRole.editor,
      members: {
        'user_current': MemberRole.owner,
        'user_alex': MemberRole.editor,
        'user_sam': MemberRole.viewer,
      },
      dayLocations: {
        Trip.dateToKey(day1): ['Japan', 'Tokyo'],
        Trip.dateToKey(day2): ['Japan', 'Tokyo'],
        Trip.dateToKey(day3): ['Japan', 'Kyoto'],
        Trip.dateToKey(day4): ['Japan', 'Kyoto'],
        Trip.dateToKey(day5): ['Japan', 'Osaka'],
      },
      createdAt: now.subtract(const Duration(days: 10)),
      updatedAt: now,
    );

    _trips.add(trip1);

    // Stays
    final staysList = [
      Stay(
        id: 'stay_01',
        tripId: trip1.id,
        type: StayType.hotel,
        name: 'Grand Hyatt Tokyo',
        address: '6-10-3 Roppongi, Minato City, Tokyo',
        checkInDate: day1,
        checkInTime: '15:00',
        checkOutDate: day3,
        checkOutTime: '11:00',
        confirmationCode: 'GH-82910',
        notes: 'Requested high floor non-smoking view of Tokyo Tower',
      ),
      Stay(
        id: 'stay_02',
        tripId: trip1.id,
        type: StayType.hotel,
        name: 'The Celestine Kyoto Gion',
        address: '572 Komatsucho, Higashiyama Ward, Kyoto',
        checkInDate: day3,
        checkInTime: '15:00',
        checkOutDate: day5,
        checkOutTime: '11:00',
        confirmationCode: 'CEL-4491',
        notes: 'Includes traditional Japanese breakfast',
      ),
    ];
    _stays[trip1.id] = staysList;

    // Activities
    final activitiesList = [
      // Day 1
      Activity(
        id: 'act_101',
        tripId: trip1.id,
        date: day1,
        startTime: '09:30',
        endTime: '10:45',
        title: 'Arrival at Tokyo Haneda (HND)',
        category: ActivityCategory.flight,
        location: 'Haneda Airport Terminal 3',
        bookingStatus: BookingStatus.ticketed,
        confirmationRef: 'ANA-9921',
      ),
      Activity(
        id: 'act_102',
        tripId: trip1.id,
        date: day1,
        startTime: '11:30',
        endTime: '12:30',
        title: 'Keikyu Airport Line & Monorail to Hotel',
        category: ActivityCategory.transport,
        location: 'Haneda to Roppongi',
        bookingStatus: BookingStatus.planned,
      ),
      Activity(
        id: 'act_103',
        tripId: trip1.id,
        date: day1,
        startTime: '15:00',
        title: 'Check-in & Unpack at Grand Hyatt',
        category: ActivityCategory.attraction,
        location: 'Grand Hyatt Tokyo Lobby',
        bookingStatus: BookingStatus.booked,
      ),
      Activity(
        id: 'act_104',
        tripId: trip1.id,
        date: day1,
        startTime: '18:30',
        endTime: '21:00',
        title: 'Shibuya Crossing & Izakaya Alley',
        category: ActivityCategory.dining,
        location: 'Shibuya Nonbei Yokocho',
        bookingStatus: BookingStatus.planned,
        notes: 'Try yakitori and local craft beers',
      ),

      // Day 2
      Activity(
        id: 'act_201',
        tripId: trip1.id,
        date: day2,
        startTime: '08:30',
        endTime: '10:00',
        title: 'Tsukiji Outer Market Food Crawl',
        category: ActivityCategory.dining,
        location: 'Tsukiji, Chuo City',
        bookingStatus: BookingStatus.planned,
        notes: 'Tamagoyaki & fresh sashimi bowl',
      ),
      Activity(
        id: 'act_202',
        tripId: trip1.id,
        date: day2,
        startTime: '10:30',
        endTime: '13:00',
        title: 'Senso-ji Temple & Asakusa Walking Tour',
        category: ActivityCategory.attraction,
        location: 'Asakusa, Taito City',
        bookingStatus: BookingStatus.ticketed,
        confirmationRef: 'SENSO-440',
      ),
      Activity(
        id: 'act_203',
        tripId: trip1.id,
        date: day2,
        startTime: '14:30',
        endTime: '17:00',
        title: 'Akihabara Electric Town & Retro Games',
        category: ActivityCategory.entertainment,
        location: 'Soto-Kanda, Chiyoda City',
        bookingStatus: BookingStatus.planned,
      ),
      Activity(
        id: 'act_204',
        tripId: trip1.id,
        date: day2,
        startTime: '19:00',
        endTime: '21:30',
        title: 'Roppongi Hills Mori Tower Observation Deck',
        category: ActivityCategory.attraction,
        location: 'Tokyo City View 52F',
        bookingStatus: BookingStatus.booked,
        confirmationRef: 'MORI-9102',
      ),

      // Day 3
      Activity(
        id: 'act_301',
        tripId: trip1.id,
        date: day3,
        startTime: '10:00',
        endTime: '12:15',
        title: 'Shinkansen Nozomi Bullet Train to Kyoto',
        category: ActivityCategory.transport,
        location: 'Tokyo Station -> Kyoto Station',
        bookingStatus: BookingStatus.ticketed,
        confirmationRef: 'JR-BULLET-71',
        notes: 'Reserved Car 5, Seats 8D & 8E (Mount Fuji side!)',
      ),
      Activity(
        id: 'act_302',
        tripId: trip1.id,
        date: day3,
        startTime: '15:30',
        endTime: '18:30',
        title: 'Fushimi Inari-Taisha Sunset Hike',
        category: ActivityCategory.attraction,
        location: '68 Fukakusa Yabunouchicho, Fushimi Ward',
        bookingStatus: BookingStatus.planned,
        notes: 'Hike through the 10,000 Vermilion Torii Gates',
      ),

      // Day 4
      Activity(
        id: 'act_401',
        tripId: trip1.id,
        date: day4,
        startTime: '09:00',
        endTime: '11:30',
        title: 'Kinkaku-ji (The Golden Pavilion)',
        category: ActivityCategory.attraction,
        location: 'Kinkakujicho, Kita Ward, Kyoto',
        bookingStatus: BookingStatus.ticketed,
      ),
      Activity(
        id: 'act_402',
        tripId: trip1.id,
        date: day4,
        startTime: '13:00',
        endTime: '16:00',
        title: 'Arashiyama Bamboo Grove & Monkey Park',
        category: ActivityCategory.attraction,
        location: 'Sagatenryuji, Ukyo Ward',
        bookingStatus: BookingStatus.planned,
      ),
      Activity(
        id: 'act_403',
        tripId: trip1.id,
        date: day4,
        startTime: '19:00',
        endTime: '21:30',
        title: 'Gion Kaiseki Traditional Multi-Course Dinner',
        category: ActivityCategory.dining,
        location: 'Gion Hanamikoji, Higashiyama',
        bookingStatus: BookingStatus.booked,
        confirmationRef: 'KAISEKI-202',
      ),

      // Day 5
      Activity(
        id: 'act_501',
        tripId: trip1.id,
        date: day5,
        startTime: '10:00',
        endTime: '12:00',
        title: 'Nishiki Market Souvenir Shopping',
        category: ActivityCategory.dining,
        location: 'Nakagyo Ward, Kyoto',
        bookingStatus: BookingStatus.planned,
      ),
      Activity(
        id: 'act_502',
        tripId: trip1.id,
        date: day5,
        startTime: '16:00',
        endTime: '17:30',
        title: 'Haruka Express Train to Kansai Airport (KIX)',
        category: ActivityCategory.transport,
        location: 'Kyoto Station -> KIX Airport',
        bookingStatus: BookingStatus.ticketed,
        confirmationRef: 'HARUKA-550',
      ),
      Activity(
        id: 'act_503',
        tripId: trip1.id,
        date: day5,
        startTime: '21:15',
        title: 'Overnight Flight JL060 Departure to SFO',
        category: ActivityCategory.flight,
        location: 'Kansai Int Airport Terminal 1',
        bookingStatus: BookingStatus.ticketed,
        confirmationRef: 'JAL-99882',
      ),
    ];
    _activities[trip1.id] = activitiesList;

    // Flights
    final flightsList = [
      Flight(
        id: 'flt_01',
        tripId: trip1.id,
        airline: 'All Nippon Airways',
        flightNumber: 'NH203',
        departureAirport: 'SFO (San Francisco)',
        arrivalAirport: 'HND (Tokyo Haneda)',
        departureTime: day1.subtract(const Duration(hours: 11)),
        arrivalTime: DateTime(day1.year, day1.month, day1.day, 9, 30),
        isMainArrival: true,
        terminal: 'I',
        gate: 'G102',
        seat: '18A',
        bookingRef: 'ANA-9921',
        notes: 'Includes window seat & vegetarian meal',
      ),
      Flight(
        id: 'flt_02',
        tripId: trip1.id,
        airline: 'Japan Airlines',
        flightNumber: 'JL060',
        departureAirport: 'KIX (Osaka Kansai)',
        arrivalAirport: 'SFO (San Francisco)',
        departureTime: DateTime(day5.year, day5.month, day5.day, 21, 15),
        arrivalTime: DateTime(day5.year, day5.month, day5.day + 1, 15, 05),
        isOvernight: true,
        isNightStay: false,
        isMainDeparture: true,
        terminal: '1',
        gate: '28',
        seat: '12K',
        bookingRef: 'JAL-99882',
        notes: 'Overnight flight across Pacific',
      ),
    ];
    _flights[trip1.id] = flightsList;

    // Seed Trip 2: Italian Dolce Vita (Rome, Florence & Amalfi)
    final itDay1 = DateTime(now.year, now.month, now.day + 30);
    final itDay2 = itDay1.add(const Duration(days: 1));
    final itDay3 = itDay1.add(const Duration(days: 2));
    final itDay4 = itDay1.add(const Duration(days: 3));
    final itDay5 = itDay1.add(const Duration(days: 4));
    final itDay6 = itDay1.add(const Duration(days: 5));

    final trip2 = Trip(
      id: 'trip_italy_2026',
      title: 'Italian Dolce Vita: Rome, Florence & Amalfi',
      destination: 'Rome, Florence & Positano, Italy',
      startDate: itDay1,
      endDate: itDay6,
      coverImageUrl:
          'https://images.unsplash.com/photo-1529260830199-42c24126f198?auto=format&fit=crop&w=1200&q=80',
      ownerId: 'user_current',
      inviteCode: 'ITA-4029',
      defaultInviteRole: MemberRole.editor,
      members: {
        'user_current': MemberRole.owner,
        'user_sophia': MemberRole.editor,
        'user_marco': MemberRole.viewer,
      },
      dayLocations: {
        Trip.dateToKey(itDay1): ['Italy', 'Rome'],
        Trip.dateToKey(itDay2): ['Italy', 'Rome', 'Vatican City'],
        Trip.dateToKey(itDay3): ['Italy', 'Florence'],
        Trip.dateToKey(itDay4): ['Italy', 'Florence'],
        Trip.dateToKey(itDay5): ['Italy', 'Positano'],
        Trip.dateToKey(itDay6): ['Italy', 'Naples'],
      },
      createdAt: now.subtract(const Duration(days: 5)),
      updatedAt: now,
    );
    _trips.add(trip2);

    final itStays = [
      Stay(
        id: 'stay_it_01',
        tripId: trip2.id,
        type: StayType.hotel,
        name: 'Hotel Artemide',
        address: 'Via Nazionale, 22, 00184 Roma RM, Italy',
        checkInDate: itDay1,
        checkInTime: '14:00',
        checkOutDate: itDay3,
        checkOutTime: '11:00',
        confirmationCode: 'ART-99214',
        notes: 'Includes rooftop panoramic breakfast overlooking Rome',
      ),
      Stay(
        id: 'stay_it_02',
        tripId: trip2.id,
        type: StayType.hotel,
        name: 'Villa Cora',
        address: 'Viale Machiavelli, 18, 50125 Firenze FI, Italy',
        checkInDate: itDay3,
        checkInTime: '15:00',
        checkOutDate: itDay5,
        checkOutTime: '12:00',
        confirmationCode: 'CORA-7741',
        notes: 'Historic 19th-century villa with heated outdoor pool and gardens',
      ),
      Stay(
        id: 'stay_it_03',
        tripId: trip2.id,
        type: StayType.rental,
        name: 'Le Sirenuse Villa',
        address: 'Via Cristoforo Colombo, 30, 84017 Positano SA, Italy',
        checkInDate: itDay5,
        checkInTime: '16:00',
        checkOutDate: itDay6,
        checkOutTime: '11:00',
        confirmationCode: 'SIR-3011',
        notes: 'Cliffside private balcony overlooking the Mediterranean Sea',
      ),
    ];
    _stays[trip2.id] = itStays;

    final itFlights = [
      Flight(
        id: 'flt_it_01',
        tripId: trip2.id,
        airline: 'Delta Air Lines',
        flightNumber: 'DL148',
        departureAirport: 'JFK (New York)',
        arrivalAirport: 'FCO (Rome)',
        departureTime: DateTime(itDay1.year, itDay1.month, itDay1.day - 1, 18, 30),
        arrivalTime: DateTime(itDay1.year, itDay1.month, itDay1.day, 08, 45),
        isOvernight: true,
        isMainArrival: true,
        terminal: '4',
        gate: 'B22',
        seat: '14B',
        bookingRef: 'DL-ITA882',
        notes: 'Transatlantic non-stop flight to Rome',
      ),
      Flight(
        id: 'flt_it_02',
        tripId: trip2.id,
        airline: 'Air France',
        flightNumber: 'AF432',
        departureAirport: 'NAP (Naples)',
        arrivalAirport: 'JFK (New York)',
        departureTime: DateTime(itDay6.year, itDay6.month, itDay6.day, 12, 15),
        arrivalTime: DateTime(itDay6.year, itDay6.month, itDay6.day, 19, 40),
        isOvernight: false,
        isMainDeparture: true,
        terminal: '1',
        gate: 'C12',
        seat: '18A',
        bookingRef: 'AF-99104',
        notes: 'Return flight via Paris Charles de Gaulle',
      ),
    ];
    _flights[trip2.id] = itFlights;

    final itActivities = [
      Activity(
        id: 'act_it_101',
        tripId: trip2.id,
        date: itDay1,
        startTime: '10:00',
        endTime: '12:30',
        title: 'Arrival & Private Transfer to Hotel Artemide',
        category: ActivityCategory.transport,
        location: 'FCO Airport to Rome City Center',
        bookingStatus: BookingStatus.ticketed,
        confirmationRef: 'LIMO-ROM-11',
      ),
      Activity(
        id: 'act_it_102',
        tripId: trip2.id,
        date: itDay1,
        startTime: '16:00',
        endTime: '19:00',
        title: 'Colosseum & Roman Forum Gladiator Arena Tour',
        category: ActivityCategory.attraction,
        location: 'Piazza del Colosseo, 1',
        bookingStatus: BookingStatus.ticketed,
        confirmationRef: 'ROMA-GLAD-01',
      ),
      Activity(
        id: 'act_it_103',
        tripId: trip2.id,
        date: itDay1,
        startTime: '20:00',
        endTime: '22:30',
        title: 'Trastevere Sunset Food & Wine Tasting Walk',
        category: ActivityCategory.dining,
        location: 'Piazza Santa Maria in Trastevere',
        bookingStatus: BookingStatus.booked,
      ),
      Activity(
        id: 'act_it_201',
        tripId: trip2.id,
        date: itDay2,
        startTime: '09:00',
        endTime: '12:30',
        title: 'Vatican Museums & Sistine Chapel Private Early Entry',
        category: ActivityCategory.attraction,
        location: 'Vatican City',
        bookingStatus: BookingStatus.ticketed,
        confirmationRef: 'VAT-8842',
      ),
      Activity(
        id: 'act_it_202',
        tripId: trip2.id,
        date: itDay2,
        startTime: '15:00',
        endTime: '17:30',
        title: 'Pantheon & Piazza Navona Gelato Crawl',
        category: ActivityCategory.dining,
        location: 'Piazza della Rotonda',
        bookingStatus: BookingStatus.planned,
      ),
      Activity(
        id: 'act_it_301',
        tripId: trip2.id,
        date: itDay3,
        startTime: '10:30',
        endTime: '12:10',
        title: 'Frecciarossa 1000 High-Speed Train to Florence',
        category: ActivityCategory.transport,
        location: 'Roma Termini -> Firenze S.M. Novella',
        bookingStatus: BookingStatus.ticketed,
        confirmationRef: 'TREN-9102',
        notes: 'Executive Class, Car 1, Seats 3 & 4',
      ),
      Activity(
        id: 'act_it_302',
        tripId: trip2.id,
        date: itDay3,
        startTime: '15:00',
        endTime: '17:30',
        title: 'Uffizi Gallery Renaissance Masterpieces Tour',
        category: ActivityCategory.attraction,
        location: 'Piazzale degli Uffizi, 6',
        bookingStatus: BookingStatus.ticketed,
        confirmationRef: 'UFFIZI-4421',
      ),
      Activity(
        id: 'act_it_401',
        tripId: trip2.id,
        date: itDay4,
        startTime: '09:30',
        endTime: '12:00',
        title: 'Florence Duomo Brunelleschi Dome Climb',
        category: ActivityCategory.attraction,
        location: 'Piazza del Duomo, Firenze',
        bookingStatus: BookingStatus.ticketed,
        confirmationRef: 'DUOMO-199',
      ),
      Activity(
        id: 'act_it_402',
        tripId: trip2.id,
        date: itDay4,
        startTime: '18:30',
        endTime: '21:00',
        title: 'Tuscan Sunset & Chianti Wine at Piazzale Michelangelo',
        category: ActivityCategory.dining,
        location: 'Piazzale Michelangelo, Firenze',
        bookingStatus: BookingStatus.planned,
      ),
      Activity(
        id: 'act_it_501',
        tripId: trip2.id,
        date: itDay5,
        startTime: '09:00',
        endTime: '13:00',
        title: 'Scenic Coastal Drive to Amalfi Coast',
        category: ActivityCategory.transport,
        location: 'Florence to Positano',
        bookingStatus: BookingStatus.booked,
        confirmationRef: 'VAN-AMALFI-2',
      ),
      Activity(
        id: 'act_it_502',
        tripId: trip2.id,
        date: itDay5,
        startTime: '19:30',
        endTime: '22:00',
        title: 'Sunset Cliffside Dinner at La Sponda',
        category: ActivityCategory.dining,
        location: 'Positano, Amalfi Coast',
        bookingStatus: BookingStatus.booked,
        notes: 'Table by the candle-lit cliff window',
      ),
    ];
    _activities[trip2.id] = itActivities;
  }

  StreamController<List<Stay>> _getStaysController(String tripId) {
    return _staysControllers.putIfAbsent(
      tripId,
      () => StreamController<List<Stay>>.broadcast(),
    );
  }

  StreamController<List<Activity>> _getActivitiesController(String tripId) {
    return _activitiesControllers.putIfAbsent(
      tripId,
      () => StreamController<List<Activity>>.broadcast(),
    );
  }

  StreamController<List<Flight>> _getFlightsController(String tripId) {
    return _flightsControllers.putIfAbsent(
      tripId,
      () => StreamController<List<Flight>>.broadcast(),
    );
  }

  @override
  Stream<List<Trip>> watchTripsForUser(String userId) {
    // Return stream seeded with current trips
    Future.microtask(() => _tripsController.add(List.unmodifiable(_trips)));
    return _tripsController.stream;
  }

  @override
  Future<List<Trip>> getTripsForUser(String userId) async {
    return List.unmodifiable(_trips);
  }

  @override
  Future<Trip?> getTripById(String tripId) async {
    try {
      return _trips.firstWhere((t) => t.id == tripId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Trip?> getTripByInviteCode(String inviteCode) async {
    final cleanCode = inviteCode.trim().toUpperCase();
    try {
      return _trips.firstWhere((t) => t.inviteCode.toUpperCase() == cleanCode);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Trip> createTrip(Trip trip) async {
    final idx = _trips.indexWhere((t) => t.id == trip.id);
    if (idx != -1) {
      _trips[idx] = trip;
    } else {
      _trips.insert(0, trip);
    }
    _tripsController.add(List.unmodifiable(_trips));
    return trip;
  }

  @override
  Future<void> updateTrip(Trip trip) async {
    final idx = _trips.indexWhere((t) => t.id == trip.id);
    if (idx != -1) {
      _trips[idx] = trip;
      _tripsController.add(List.unmodifiable(_trips));
    }
  }

  @override
  Future<void> deleteTrip(String tripId) async {
    _trips.removeWhere((t) => t.id == tripId);
    _tripsController.add(List.unmodifiable(_trips));
  }

  @override
  Future<bool> joinTripWithCode(String inviteCode, String userId) async {
    final trip = await getTripByInviteCode(inviteCode);
    if (trip == null) return false;

    final updatedMembers = Map<String, MemberRole>.from(trip.members);
    updatedMembers[userId] = trip.defaultInviteRole;

    final updatedTrip = trip.copyWith(members: updatedMembers, updatedAt: DateTime.now());
    await updateTrip(updatedTrip);
    return true;
  }

  @override
  Future<void> updateDayLocations(String tripId, DateTime date, List<String> locations) async {
    final idx = _trips.indexWhere((t) => t.id == tripId);
    if (idx != -1) {
      final trip = _trips[idx];
      final newDayLocations = Map<String, List<String>>.from(trip.dayLocations);
      final key = Trip.dateToKey(date);
      if (locations.isEmpty) {
        newDayLocations.remove(key);
      } else {
        newDayLocations[key] = List<String>.from(locations);
      }
      final updated = trip.copyWith(
        dayLocations: newDayLocations,
        updatedAt: DateTime.now(),
      );
      _trips[idx] = updated;
      _tripsController.add(List.unmodifiable(_trips));
    }
  }

  // Stays
  @override
  Stream<List<Stay>> watchStays(String tripId) {
    final ctrl = _getStaysController(tripId);
    Future.microtask(() => ctrl.add(List.unmodifiable(_stays[tripId] ?? [])));
    return ctrl.stream;
  }

  @override
  Future<List<Stay>> getStays(String tripId) async {
    return List.unmodifiable(_stays[tripId] ?? []);
  }

  @override
  Future<void> addStay(Stay stay) async {
    final list = _stays.putIfAbsent(stay.tripId, () => []);
    final idx = list.indexWhere((s) => s.id == stay.id);
    if (idx != -1) {
      list[idx] = stay;
    } else {
      list.add(stay);
    }
    _getStaysController(stay.tripId).add(List.unmodifiable(list));
  }

  @override
  Future<void> updateStay(Stay stay) async {
    final list = _stays[stay.tripId];
    if (list != null) {
      final idx = list.indexWhere((s) => s.id == stay.id);
      if (idx != -1) {
        list[idx] = stay;
        _getStaysController(stay.tripId).add(List.unmodifiable(list));
      }
    }
  }

  @override
  Future<void> deleteStay(String tripId, String stayId) async {
    Stay? removedStay;
    final list = _stays[tripId];
    if (list != null) {
      final idx = list.indexWhere((s) => s.id == stayId);
      if (idx != -1) {
        removedStay = list.removeAt(idx);
        _getStaysController(tripId).add(List.unmodifiable(list));
      }
    }

    // Also handle synthesized flight stays or flight-backed stays
    final flightsList = _flights[tripId];
    if (flightsList != null) {
      bool flightUpdated = false;
      String? targetFlightId;
      if (stayId.startsWith('stay_flight_')) {
        targetFlightId = stayId.substring('stay_flight_'.length);
      } else if (stayId.startsWith('flight_stay_')) {
        targetFlightId = stayId.substring('flight_stay_'.length);
      } else if (removedStay?.overnightFlight != null) {
        targetFlightId = removedStay!.overnightFlight!.id;
      }

      for (int i = 0; i < flightsList.length; i++) {
        final f = flightsList[i];
        if (f.id == targetFlightId ||
            (removedStay != null &&
                removedStay.overnightFlight != null &&
                f.airline == removedStay.overnightFlight?.airline &&
                f.flightNumber == removedStay.overnightFlight?.flightNumber)) {
          flightsList[i] = f.copyWith(isNightStay: false);
          flightUpdated = true;
        }
      }

      if (flightUpdated) {
        _getFlightsController(tripId).add(List.unmodifiable(flightsList));
      }
    }
  }

  // Activities
  @override
  Stream<List<Activity>> watchActivities(String tripId) {
    final ctrl = _getActivitiesController(tripId);
    Future.microtask(() => ctrl.add(List.unmodifiable(_activities[tripId] ?? [])));
    return ctrl.stream;
  }

  @override
  Future<List<Activity>> getActivities(String tripId) async {
    return List.unmodifiable(_activities[tripId] ?? []);
  }

  @override
  Future<void> addActivity(Activity activity) async {
    final list = _activities.putIfAbsent(activity.tripId, () => []);
    final idx = list.indexWhere((a) => a.id == activity.id);
    if (idx != -1) {
      list[idx] = activity;
    } else {
      list.add(activity);
    }
    _getActivitiesController(activity.tripId).add(List.unmodifiable(list));
  }

  @override
  Future<void> updateActivity(Activity activity) async {
    final list = _activities[activity.tripId];
    if (list != null) {
      final idx = list.indexWhere((a) => a.id == activity.id);
      if (idx != -1) {
        list[idx] = activity;
        _getActivitiesController(activity.tripId).add(List.unmodifiable(list));
      }
    }
  }

  @override
  Future<void> deleteActivity(String tripId, String activityId) async {
    final list = _activities[tripId];
    if (list != null) {
      list.removeWhere((a) => a.id == activityId);
      _getActivitiesController(tripId).add(List.unmodifiable(list));
    }
  }

  // Flights
  @override
  Stream<List<Flight>> watchFlights(String tripId) {
    final ctrl = _getFlightsController(tripId);
    Future.microtask(() => ctrl.add(List.unmodifiable(_flights[tripId] ?? [])));
    return ctrl.stream;
  }

  @override
  Future<List<Flight>> getFlights(String tripId) async {
    return List.unmodifiable(_flights[tripId] ?? []);
  }

  @override
  Future<void> addFlight(Flight flight) async {
    final list = _flights.putIfAbsent(flight.tripId, () => []);
    final idx = list.indexWhere((f) => f.id == flight.id);
    if (idx != -1) {
      list[idx] = flight;
    } else {
      list.add(flight);
    }
    _getFlightsController(flight.tripId).add(List.unmodifiable(list));
  }

  @override
  Future<void> updateFlight(Flight flight) async {
    final list = _flights[flight.tripId];
    if (list != null) {
      final idx = list.indexWhere((f) => f.id == flight.id);
      if (idx != -1) {
        list[idx] = flight;
        _getFlightsController(flight.tripId).add(List.unmodifiable(list));
      }
    }
  }

  @override
  Future<void> deleteFlight(String tripId, String flightId) async {
    final list = _flights[tripId];
    if (list != null) {
      list.removeWhere((f) => f.id == flightId);
      _getFlightsController(tripId).add(List.unmodifiable(list));
    }
  }
}
