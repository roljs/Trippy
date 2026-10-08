import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../state/trip_providers.dart';

void showUserAccountDialog(BuildContext context, WidgetRef ref) {
  final user = ref.read(authServiceProvider).currentUser;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryContainer,
            backgroundImage: user?.photoURL != null
                ? NetworkImage(user!.photoURL!)
                : null,
            child: user?.photoURL == null
                ? Text(
                    (user?.displayName?.isNotEmpty == true
                            ? user!.displayName![0]
                            : user?.isAnonymous == true
                                ? 'G'
                                : 'U')
                        .toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ??
                      (user?.isAnonymous == true
                          ? 'Guest User'
                          : user == null
                              ? 'Not Signed In'
                              : 'Authenticated User'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (user?.email != null)
                  Text(
                    user!.email!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user == null) ...[
            const Text(
              'Sign in to synchronize and backup your trips to the cloud.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ref.read(authServiceProvider).signInWithGoogle();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sign-in failed: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Sign in with Google'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ref.read(authServiceProvider).signInAnonymously();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Guest sign-in failed: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.person_outline, size: 18),
              label: const Text('Continue as Guest'),
            ),
          ] else if (user.isAnonymous == true) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You are using a temporary guest account. Sign in with Google to save your trips permanently.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ref.read(authServiceProvider).signInWithGoogle();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sign-in failed: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Upgrade with Google'),
            ),
            const SizedBox(height: 8),
          ],
          if (user != null)
            Text(
              'UID: ${user.uid}',
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
        if (user != null)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authServiceProvider).signOut();
            },
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Sign Out'),
          ),
      ],
    ),
  );
}

class UserAccountButton extends ConsumerWidget {
  const UserAccountButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authServiceProvider).currentUser;

    return IconButton(
      tooltip: 'Account',
      icon: CircleAvatar(
        radius: 14,
        backgroundColor: AppColors.primaryContainer,
        backgroundImage: currentUser?.photoURL != null
            ? NetworkImage(currentUser!.photoURL!)
            : null,
        child: currentUser?.photoURL == null
            ? Text(
                (currentUser?.displayName?.isNotEmpty == true
                        ? currentUser!.displayName![0]
                        : currentUser?.isAnonymous == true
                            ? 'G'
                            : 'U')
                    .toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              )
            : null,
      ),
      onPressed: () => showUserAccountDialog(context, ref),
    );
  }
}
