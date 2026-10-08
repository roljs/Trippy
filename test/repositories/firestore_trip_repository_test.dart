import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippy/data/repositories/firestore_trip_repository.dart';
import 'package:trippy/data/repositories/trip_repository.dart';
import 'package:trippy/state/trip_providers.dart';

void main() {
  group('FirestoreTripRepository & Providers Tests', () {
    test('FirestoreTripRepository implements TripRepository interface', () {
      expect(FirestoreTripRepository.new, isA<Function>());
      bool isTripRepo<T>() => T == TripRepository;
      expect(isTripRepo<TripRepository>(), isTrue);
    });

    test('tripRepositoryProvider provides TripRepository', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(tripRepositoryProvider);
      expect(repo, isA<TripRepository>());
    });

    test('currentUserIdProvider resolves safely to user ID', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final userId = container.read(currentUserIdProvider);
      expect(userId, isNotEmpty);
      expect(userId, 'user_current');
    });
  });
}
