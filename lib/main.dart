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
  await cloud.initialize();
  final state = AppState(cloud: cloud);
  await state.initialize();
  runApp(SaapaduApp(state: state));
}

class SaapaduApp extends StatelessWidget {
  const SaapaduApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Saapadu — Food & wellness tracker',
        theme: buildTheme(),
        home: !state.ready
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : state.cloud.configured && !state.cloud.signedIn
                ? LoginScreen(cloud: state.cloud)
                : state.cloud.configured && !state.cloud.authorized
                    ? AccessDeniedScreen(cloud: state.cloud)
                    : state.profile == null
                        ? OnboardingScreen(state: state)
                        : HomeShell(state: state),
      ),
    );
  }
}
