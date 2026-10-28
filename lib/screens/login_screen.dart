import 'package:flutter/material.dart';

import '../cloud_sync_service.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.cloud});
  final CloudSyncService cloud;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool working = false;
  String? error;

  Future<void> _signIn() async {
    if (working) return;
    setState(() {
      working = true;
      error = null;
    });
    try {
      await widget.cloud.signInWithGoogle();
    } catch (_) {
      if (mounted) {
        setState(() {
          working = false;
          error =
              'Google sign-in could not open. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: SafeArea(child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 860;
        final story = Container(
            padding: EdgeInsets.all(wide ? 48 : 28),
            decoration: BoxDecoration(
                color: AppColors.forest,
                borderRadius: BorderRadius.circular(32)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Row(children: [
                    Icon(Icons.spa_rounded, color: AppColors.lime, size: 30),
                    SizedBox(width: 10),
                    Text('saapadu.',
                        style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Sora',
                            fontSize: 27,
                            fontWeight: FontWeight.w700))
                  ]),
                  const SizedBox(height: 42),
                  const Text('Your plate.\nYour pace.',
                      style: TextStyle(
                          fontFamily: 'Sora',
                          color: Colors.white,
                          fontSize: 47,
                          height: 1.14,
                          letterSpacing: -2,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 18),
                  Text(
                      'Familiar food. Thoughtful routines.\nA little more balance, every day.',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: .75),
                          fontSize: 16,
                          height: 1.6)),
                  const SizedBox(height: 30),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final feature in [
                      (Icons.ramen_dining_rounded, 'South Indian food diary'),
                      (Icons.water_drop_outlined, 'Daily wellness'),
                      (Icons.timelapse_rounded, 'Fasting windows'),
                      (Icons.show_chart_rounded, 'Your progress')
                    ])
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(feature.$1, size: 17, color: AppColors.lime),
                            const SizedBox(width: 8),
                            Text(feature.$2,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12))
                          ]))
                  ]),
                  const SizedBox(height: 36),
                  Text('BUILT AROUND THE WAY YOU EAT.',
                      style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 2,
                          color: Colors.white.withValues(alpha: .65),
                          fontWeight: FontWeight.w700)),
                ]));
        final entry = Padding(
            padding: EdgeInsets.all(wide ? 48 : 12),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('YOUR PRIVATE WELLNESS SPACE',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.7,
                          fontWeight: FontWeight.w800,
                          color: AppColors.forest)),
                  const SizedBox(height: 16),
                  Text('A fresh page.\nA familiar routine.',
                      style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 18),
                  const Text(
                      'Log the meals you love, understand your nutrition and bring your daily rhythms together. Sign in to keep your history across devices.',
                      style: TextStyle(color: AppColors.muted, height: 1.7)),
                  const SizedBox(height: 30),
                  FilledButton.icon(
                      onPressed: working ? null : _signIn,
                      icon: Icon(working
                          ? Icons.hourglass_top_rounded
                          : Icons.login_rounded),
                      label: Text(working
                          ? 'Opening Google…'
                          : 'Continue with Google')),
                  if (error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Semantics(
                            liveRegion: true,
                            child: Text(error!,
                                style: const TextStyle(
                                    color: AppColors.terracotta)))),
                  const SizedBox(height: 20),
                  const Row(children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 16, color: AppColors.muted),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            'Your account. Your diary. No ads or analytics.',
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 12)))
                  ]),
                  const SizedBox(height: 40),
                  const Text(
                      'Calories and activity figures are estimates. Your personal records belong to your account.',
                      style: TextStyle(
                          color: AppColors.muted, fontSize: 11, height: 1.6)),
                ]));
        return Center(
            child: SingleChildScrollView(
                padding: EdgeInsets.all(wide ? 34 : 18),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                                Expanded(child: story),
                                Expanded(child: entry)
                              ])
                        : Column(children: [
                            story,
                            const SizedBox(height: 24),
                            entry
                          ]))));
      })));
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
