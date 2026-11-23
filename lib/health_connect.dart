import 'health_import.dart';
import 'platform/health_connect_stub.dart'
    if (dart.library.io) 'platform/health_connect_android.dart' as impl;

enum HealthConnectAvailability { unsupported, needsInstall, available }

/// Read-only bridge to Health Connect. The app never writes health records.
abstract class HealthBridge {
  const HealthBridge();

  /// False on web and in tests; the UI hides Health Connect then.
  bool get supported => true;
  Future<HealthConnectAvailability> availability();
  Future<bool> requestAccess();
  Future<bool> hasAccess();
  Future<void> openInstall();
  Future<HealthImport> read(DateTime from, DateTime to);

  /// Real Health Connect on Android, a no-op elsewhere (web, tests).
  static HealthBridge platform() => impl.createHealthBridge();
}

class NoHealthBridge extends HealthBridge {
  const NoHealthBridge();
  @override
  bool get supported => false;
  @override
  Future<HealthConnectAvailability> availability() async =>
      HealthConnectAvailability.unsupported;
  @override
  Future<bool> requestAccess() async => false;
  @override
  Future<bool> hasAccess() async => false;
  @override
  Future<void> openInstall() async {}
  @override
  Future<HealthImport> read(DateTime from, DateTime to) async =>
      const HealthImport(fromKey: '9999-12-31', toKey: '0000-01-01');
}
