import 'package:flutter/material.dart';

import '../cloud_sync_service.dart';
import '../theme.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.cloud});
  final CloudSyncService cloud;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(
                              color: AppColors.forest,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.spa_outlined,
                                color: AppColors.lime),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('Your history, wherever you continue.',
                            style: Theme.of(context).textTheme.displaySmall),
                        const SizedBox(height: 14),
                        const Text(
                          'Sign in with the approved Google account. Your browser keeps an offline copy and syncs the same diary, weight history, workouts, and targets to the cloud.',
                          style: TextStyle(color: AppColors.muted, height: 1.5),
                        ),
                        const SizedBox(height: 26),
                        FilledButton.icon(
                          onPressed: cloud.signInWithGoogle,
                          icon: const Icon(Icons.login),
                          label: const Text('Continue with Google'),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Only the configured account can synchronize this private tracker.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key, required this.cloud});
  final CloudSyncService cloud;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.no_accounts_outlined,
                      size: 54, color: AppColors.terracotta),
                  const SizedBox(height: 16),
                  Text('This account is not approved.',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign out and use the Google account configured for this tracker.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.tonal(
                    onPressed: cloud.signOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
