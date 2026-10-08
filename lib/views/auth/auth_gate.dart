import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/mock_trip_repository.dart';
import '../../state/trip_providers.dart';
import '../common/app_nav_scaffold.dart';
import 'sign_in_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(tripRepositoryProvider);
    // In mock repository mode (such as test environments), proceed directly
    if (repo is MockTripRepository) {
      return const AppNavScaffold();
    }

    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          return const AppNavScaffold();
        }
        return const SignInScreen();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SignInScreen(initialError: e.toString()),
    );
  }
}
