import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'cloud_sync_service.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['DM Sans'],
        await rootBundle.loadString('assets/fonts/OFL-DMSans.txt'));
    yield LicenseEntryWithLineBreaks(
        ['Sora'], await rootBundle.loadString('assets/fonts/OFL-Sora.txt'));
  });
  final cloud = CloudSyncService();
  final state = AppState(cloud: cloud);
  runApp(SaapaduApp(
      state: state,
      bootstrap: () async {
        await cloud.initialize();
        await state.initialize();
      }));
}

class SaapaduApp extends StatefulWidget {
  const SaapaduApp({super.key, required this.state, this.bootstrap});
  final AppState state;
  final Future<void> Function()? bootstrap;

  @override
  State<SaapaduApp> createState() => _SaapaduAppState();
}

class _SaapaduAppState extends State<SaapaduApp> {
  bool _continueLocally = false;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    widget.state.cloud.addListener(_onAuthChanged);
    if (widget.bootstrap != null) unawaited(_startApp());
  }

  Future<void> _startApp() async {
    if (_startupError != null && mounted) setState(() => _startupError = null);
    try {
      await widget.bootstrap?.call();
    } catch (_) {
      if (mounted) {
        setState(() => _startupError =
            'Saapadu could not open your device diary. Try again; your saved records have not been cleared.');
      }
    }
  }

  void _onAuthChanged() {
    // A later explicit sign-out returns to the choice screen rather than
    // inheriting a previous guest-mode choice. AppState owns account isolation.
    if (widget.state.cloud.signedIn) _continueLocally = false;
  }

  @override
  void dispose() {
    widget.state.cloud.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Saapadu — Food & wellness tracker',
        theme: buildTheme(),
        home: _startupError != null
            ? Scaffold(
                body: Center(
                    child: Padding(
                        padding: const EdgeInsets.all(28),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.refresh_rounded, size: 40),
                          const SizedBox(height: 16),
                          Text(_startupError!, textAlign: TextAlign.center),
                          const SizedBox(height: 18),
                          FilledButton(
                              onPressed: _startApp,
                              child: const Text('Try again')),
                        ]))))
            : !state.ready || (state.profile == null && state.cloudRestoring)
                ? const Scaffold(
                    body: Center(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Opening your diary…')
                      ])))
                : state.cloud.configured &&
                        state.cloud.signedIn &&
                        !state.cloud.authorized
                    ? AccessDeniedScreen(cloud: state.cloud)
                    : state.cloud.configured &&
                            !state.cloud.signedIn &&
                            (kIsWeb ||
                                (!_continueLocally &&
                                    (state.profile == null ||
                                        state.cloud.userRequestedSignOut)))
                        ? LoginScreen(
                            cloud: state.cloud,
                            onContinueLocally: kIsWeb
                                ? null
                                : () => setState(() => _continueLocally = true),
                          )
                        : state.profile == null
                            ? OnboardingScreen(state: state)
                            : HomeShell(state: state),
      ),
    );
  }
}
