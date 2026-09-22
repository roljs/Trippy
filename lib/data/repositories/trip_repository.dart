import '../../models/models.dart';

abstract class TripRepository {
  Stream<List<Trip>> watchTripsForUser(String userId);
  Future<List<Trip>> getTripsForUser(String userId);
  Future<Trip?> getTripById(String tripId);
  Future<Trip?> getTripByInviteCode(String inviteCode);
  Future<Trip> createTrip(Trip trip);
  Future<void> updateTrip(Trip trip);
  Future<void> deleteTrip(String tripId);
  Future<bool> joinTripWithCode(String inviteCode, String userId);
  Future<void> updateDayLocations(String tripId, DateTime date, List<String> locations);

  // Stays
  Stream<List<Stay>> watchStays(String tripId);
  Future<List<Stay>> getStays(String tripId);
  Future<void> addStay(Stay stay);
  Future<void> updateStay(Stay stay);
  Future<void> deleteStay(String tripId, String stayId);

  // Activities
  Stream<List<Activity>> watchActivities(String tripId);
  Future<List<Activity>> getActivities(String tripId);
  Future<void> addActivity(Activity activity);
  Future<void> updateActivity(Activity activity);
  Future<void> deleteActivity(String tripId, String activityId);

  // Flights
  Stream<List<Flight>> watchFlights(String tripId);
  Future<List<Flight>> getFlights(String tripId);
  Future<void> addFlight(Flight flight);
  Future<void> updateFlight(Flight flight);
  Future<void> deleteFlight(String tripId, String flightId);
}
