import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/date_formatters.dart';
import '../data/repositories/firestore_trip_repository.dart';
import '../data/repositories/mock_trip_repository.dart';
import '../data/repositories/trip_repository.dart';
import '../models/models.dart';

import '../services/auth/auth_service.dart';

// Repository Provider
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  try {
    return FirestoreTripRepository(FirebaseFirestore.instance);
  } catch (_) {
    return MockTripRepository();
  }
});

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Stream of auth state changes from Firebase
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// Current active user ID linked to FirebaseAuth
final currentUserIdProvider = Provider<String>((ref) {
  final authUser = ref.watch(authStateChangesProvider).asData?.value;
  final current =
      authUser?.uid ?? ref.watch(authServiceProvider).currentUser?.uid;
  if (current != null && current.isNotEmpty) {
    return current;
  }
  final repo = ref.watch(tripRepositoryProvider);
  if (repo is MockTripRepository) {
    return 'user_current';
  }
  return '';
});

// Selected Trip ID Notifier
class ActiveTripIdNotifier extends Notifier<String?> {
  @override
  String? build() => 'trip_japan_2026';

  void selectTrip(String? id) => state = id;
}

final activeTripIdProvider =
    NotifierProvider<ActiveTripIdNotifier, String?>(ActiveTripIdNotifier.new);

// Itinerary View Mode: Full View vs Compact View vs Map View vs Calendar View
enum ItineraryViewMode { full, compact, map, calendar }

class ItineraryViewModeNotifier extends Notifier<ItineraryViewMode> {
  @override
  ItineraryViewMode build() => ItineraryViewMode.full;

  void setMode(ItineraryViewMode mode) => state = mode;
}

final itineraryViewModeProvider =
    NotifierProvider<ItineraryViewModeNotifier, ItineraryViewMode>(
        ItineraryViewModeNotifier.new);

// Navigation Tab Index: 0 = Day Planner, 1 = Itinerary, 2 = Flights, 3 = Stays, 4 = Activities, 5 = Trips
class NavTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) => state = index;
}

final navTabIndexProvider =
    NotifierProvider<NavTabIndexNotifier, int>(NavTabIndexNotifier.new);

// Focused Trip Date for cross-view navigation (Day Planner <-> Itinerary <-> Calendar)
class FocusedTripDateNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void setDate(DateTime? date) => state = date;
}

final focusedTripDateProvider =
    NotifierProvider<FocusedTripDateNotifier, DateTime?>(
        FocusedTripDateNotifier.new);

// Stream of all trips for current user
final userTripsProvider = StreamProvider<List<Trip>>((ref) {
  final repo = ref.watch(tripRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId.isEmpty) {
    return Stream.value(const <Trip>[]);
  }
  return repo.watchTripsForUser(userId);
});

// Currently selected Trip
final activeTripProvider = Provider<Trip?>((ref) {
  final tripId = ref.watch(activeTripIdProvider);
  if (tripId == null) return null;

  final tripsAsync = ref.watch(userTripsProvider);
  return tripsAsync.when(
    data: (trips) {
      try {
        return trips.firstWhere((t) => t.id == tripId);
      } catch (_) {
        return trips.isNotEmpty ? trips.first : null;
      }
    },
    loading: () => null,
    error: (_, _) => null,
  );
});

// Active User's Role in Selected Trip
final activeTripRoleProvider = Provider<MemberRole>((ref) {
  final trip = ref.watch(activeTripProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (trip == null) return MemberRole.viewer;
  return trip.getRole(userId) ?? MemberRole.viewer;
});

// Permission check: Can current user edit the active trip?
final canEditActiveTripProvider = Provider<bool>((ref) {
  final role = ref.watch(activeTripRoleProvider);
  return role.canEdit;
});

// Active Trip Stays Stream
final activeTripStaysProvider = StreamProvider<List<Stay>>((ref) {
  final tripId = ref.watch(activeTripIdProvider);
  if (tripId == null) return Stream.value([]);
  final repo = ref.watch(tripRepositoryProvider);
  return repo.watchStays(tripId);
});

// Active Trip Stays, sorted chronologically by check-in date/time, including synthesized stays for flights marked isNightStay
final sortedActiveTripStaysProvider = Provider<AsyncValue<List<Stay>>>((ref) {
  final staysAsync = ref.watch(activeTripStaysProvider);
  final flightsAsync = ref.watch(activeTripFlightsProvider);

  if (staysAsync.isLoading && !staysAsync.hasValue) {
    return const AsyncValue.loading();
  }
  if (staysAsync.hasError) {
    return AsyncValue.error(staysAsync.error!, staysAsync.stackTrace!);
  }

  final stays = staysAsync.value ?? [];
  final flights = flightsAsync.value ?? [];
  final list = List<Stay>.from(stays);

  for (final flight in flights) {
    if (flight.isNightStay) {
      final alreadyPresent = list.any((s) =>
          s.overnightFlight?.id == flight.id ||
          s.id == 'stay_flight_${flight.id}' ||
          (s.confirmationCode == flight.bookingRef &&
              flight.bookingRef != null &&
              flight.bookingRef!.isNotEmpty));
      if (!alreadyPresent) {
        final checkInD = DateTime(flight.departureTime.year,
            flight.departureTime.month, flight.departureTime.day);
        final checkOutD = DateTime(flight.arrivalTime.year,
            flight.arrivalTime.month, flight.arrivalTime.day);
        final finalCheckOut = checkOutD.isAfter(checkInD)
            ? checkOutD
            : checkInD.add(const Duration(days: 1));

        list.add(
          Stay(
            id: 'stay_flight_${flight.id}',
            tripId: flight.tripId,
            type: StayType.overnightFlight,
            name: '${flight.airline} ${flight.flightNumber}'.trim(),
            address: '${flight.departureAirport} → ${flight.arrivalAirport}',
            checkInDate: checkInD,
            checkInTime: DateFormatters.time24.format(flight.departureTime),
            checkOutDate: finalCheckOut,
            checkOutTime: DateFormatters.time24.format(flight.arrivalTime),
            confirmationCode: flight.bookingRef,
            notes: flight.notes,
            overnightFlight: flight,
          ),
        );
      }
    }
  }

  list.sort((a, b) {
    final cmp = a.checkInDate.compareTo(b.checkInDate);
    if (cmp != 0) return cmp;
    return (a.checkInTime ?? '').compareTo(b.checkInTime ?? '');
  });
  return AsyncValue.data(list);
});

// Active Trip Activities Stream
final activeTripActivitiesProvider = StreamProvider<List<Activity>>((ref) {
  final tripId = ref.watch(activeTripIdProvider);
  if (tripId == null) return Stream.value([]);
  final repo = ref.watch(tripRepositoryProvider);
  return repo.watchActivities(tripId);
});

// Active Trip Flights Stream
final activeTripFlightsProvider = StreamProvider<List<Flight>>((ref) {
  final tripId = ref.watch(activeTripIdProvider);
  if (tripId == null) return Stream.value([]);
  final repo = ref.watch(tripRepositoryProvider);
  return repo.watchFlights(tripId);
});

// Grouped Activities by Normalized Day Date, sorted chronologically
final activitiesByDayProvider =
    Provider<Map<DateTime, List<Activity>>>((ref) {
  final activitiesAsync = ref.watch(activeTripActivitiesProvider);

  return activitiesAsync.when(
    data: (activities) {
      final map = <DateTime, List<Activity>>{};
      for (final act in activities) {
        final dayKey = DateTime(act.date.year, act.date.month, act.date.day);
        map.putIfAbsent(dayKey, () => []).add(act);
      }
      // Sort each day's activities chronologically by startDateTime
      for (final list in map.values) {
        list.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
      }
      return map;
    },
    loading: () => {},
    error: (_, _) => {},
  );
});
