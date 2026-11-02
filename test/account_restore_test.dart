import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:saapadu/app_state.dart';
import 'package:saapadu/cloud_sync_service.dart';
import 'package:saapadu/models.dart';

const ownerA = '11111111-1111-4111-8111-111111111111';
const ownerB = '22222222-2222-4222-8222-222222222222';
const profileA = Profile(
    name: 'Owner A',
    sex: 'Male',
    birthYear: 1990,
    heightCm: 175,
    currentWeightKg: 80,
    goalWeightKg: 75,
    activityLevel: 'Sedentary',
    weeklyGoalKg: .5);

class PendingCloud extends CloudSyncService {
  PendingCloud(String id) {
    _user = account(id);
  }
  late User _user;
  final pending = <String, Completer<CloudBackup?>>{};
  final uploads = <Map<String, dynamic>>[];
  static User account(String id) => User.fromJson({
        'id': id,
        'email': '$id@example.invalid',
        'aud': 'authenticated',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': '2026-11-02T00:00:00Z'
      })!;
  @override
  bool get configured => true;
  @override
  bool get authorized => true;
  @override
  User get user => _user;
  void switchTo(String id) {
    _user = account(id);
    notifyListeners();
  }

  @override
  Future<CloudBackup?> fetchBackup() =>
      pending.putIfAbsent(user.id, Completer<CloudBackup?>.new).future;
  @override
  void scheduleUpload(Future<void> Function() upload) {}
  @override
  Future<void> uploadBackup(Map<String, dynamic> payload,
      {int revision = 1}) async {
    uploads
        .add(Map<String, dynamic>.from(jsonDecode(jsonEncode(payload)) as Map));
  }
}

CloudBackup backup(Profile profile) => CloudBackup(payload: {
      'profile': profile.toJson(),
      'foodLogs': [],
      'workouts': [],
      'customFoods': [],
      'weights': [],
      'wellness': [],
      'fasting': {},
      'lastChangedAt': '2026-11-02T00:00:00Z'
    }, revision: 1, updatedAt: DateTime.utc(2026, 11, 2));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> createGuestDiary() async {
    SharedPreferences.setMockInitialValues({});
    final cloud = CloudSyncService();
    final guest = AppState(cloud: cloud);
    await guest.initialize();
    await guest.saveProfile(profileA.copyWith(name: 'Offline guest'));
    await guest.addFood(guest.foods.first, 1, 'Breakfast');
    guest.dispose();
    cloud.dispose();
  }

  Future<void> settled(AppState state) async {
    for (var i = 0; i < 40 && state.cloudRestoring; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test(
      'first link preserves older existing account history and retains the newer offline diary separately',
      () async {
    await createGuestDiary();
    final cloud = PendingCloud(ownerA);
    final state = AppState(cloud: cloud);
    await state.initialize();
    expect(state.profile, isNull);
    expect(state.cloudRestoring, true);
    await Future<void>.delayed(Duration.zero);
    final existing = backup(profileA);
    existing.payload['lastChangedAt'] = '2020-01-01T00:00:00Z';
    cloud.pending[ownerA]!.complete(existing);
    await settled(state);
    expect(state.profile!.name, 'Owner A');
    expect(state.logs, isEmpty);
    expect(cloud.uploads, isEmpty);
    final retained = jsonDecode(state.retainedGuestBackup!) as Map;
    expect((retained['profile'] as Map)['name'], 'Offline guest');
    expect(retained['foodLogs'], hasLength(1));
    expect(state.guestLinkPending, false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pending_guest_backup'), isNotNull);
    state.dispose();
    cloud.dispose();
  });
  test('failed first link retains later offline edits across a restart',
      () async {
    await createGuestDiary();
    final cloud = PendingCloud(ownerA);
    final state = AppState(cloud: cloud);
    await state.initialize();
    await Future<void>.delayed(Duration.zero);
    cloud.pending[ownerA]!.completeError(StateError('offline'));
    await settled(state);
    expect(state.profile!.name, 'Offline guest');
    expect(state.guestLinkPending, true);
    await state.addFood(state.foods.first, 1, 'Lunch');
    expect((jsonDecode(state.retainedGuestBackup!) as Map)['foodLogs'],
        hasLength(2));
    expect(cloud.uploads, isEmpty);
    state.dispose();
    cloud.dispose();

    final retryCloud = PendingCloud(ownerA);
    final restored = AppState(cloud: retryCloud);
    await restored.initialize();
    await Future<void>.delayed(Duration.zero);
    retryCloud.pending[ownerA]!.complete(backup(profileA));
    await settled(restored);
    expect(restored.profile!.name, 'Owner A');
    expect(restored.logs, isEmpty);
    expect(restored.guestLinkPending, false);
    expect(retryCloud.uploads, isEmpty);
    expect((jsonDecode(restored.retainedGuestBackup!) as Map)['foodLogs'],
        hasLength(2));
    restored.dispose();
    retryCloud.dispose();
  });
  test(
      'first link adopts the offline diary only after confirming the account has no backup',
      () async {
    await createGuestDiary();
    final cloud = PendingCloud(ownerA);
    final state = AppState(cloud: cloud);
    await state.initialize();
    await Future<void>.delayed(Duration.zero);
    expect(cloud.uploads, isEmpty);
    cloud.pending[ownerA]!.complete(null);
    await settled(state);
    expect(state.profile!.name, 'Offline guest');
    expect(state.logs, hasLength(1));
    expect(state.guestLinkPending, false);
    expect(cloud.uploads, hasLength(1));
    expect((cloud.uploads.single['profile'] as Map)['name'], 'Offline guest');
    expect(cloud.uploads.single['foodLogs'], hasLength(1));
    state.dispose();
    cloud.dispose();
  });
  test(
      'account switching clears the previous diary before notifying and ignores its late backup',
      () async {
    SharedPreferences.setMockInitialValues(
        {'cloud_user_id': ownerA, 'profile': jsonEncode(profileA.toJson())});
    final cloud = PendingCloud(ownerA);
    final state = AppState(cloud: cloud);
    await state.initialize();
    expect(state.ready, true);
    expect(state.profile!.name, 'Owner A');
    await Future<void>.delayed(Duration.zero);
    final presentedNames = <String?>[];
    state.addListener(() {
      if (cloud.user.id == ownerB) presentedNames.add(state.profile?.name);
    });
    cloud.switchTo(ownerB);
    expect(state.profile, isNull);
    expect(state.cloudRestoring, true);
    await Future<void>.delayed(Duration.zero);
    cloud.pending[ownerA]!.complete(backup(profileA));
    await Future<void>.delayed(Duration.zero);
    expect(state.profile, isNull);
    cloud.pending[ownerB]!.complete(
        backup(profileA.copyWith(name: 'Owner B', currentWeightKg: 90)));
    for (var i = 0; i < 20 && state.cloudRestoring; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(state.profile!.name, 'Owner B');
    expect(state.profile!.currentWeightKg, 90);
    expect(state.cloudRestoring, false);
    expect(presentedNames.where((name) => name == 'Owner A'), isEmpty);
    state.dispose();
    cloud.dispose();
  });
}
