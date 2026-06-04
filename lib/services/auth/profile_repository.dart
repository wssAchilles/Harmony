import 'dart:math';

import 'package:pocketbase/pocketbase.dart';

import '../../models/profile.dart';
import '../backend/backend_gateway.dart';

class ProfileRepository {
  ProfileRepository({BackendGateway? backend})
      : _backend = backend ?? backendGateway;

  final BackendGateway _backend;

  Future<void> refreshAuth() async {
    await _backend.authRefresh('profiles');
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _backend.authWithPassword('profiles', email, password);
  }

  Future<void> createTeacherProfile({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final profileId = _newProfileRecordId();
    await _backend.create('profiles', {
      'id': profileId,
      'source_id': profileId,
      'email': email,
      'password': password,
      'passwordConfirm': password,
      'full_name': fullName,
      'role': 'teacher',
      'emailVisibility': true,
      'verified': true,
    });
  }

  Future<Profile?> getProfileByUserId(String userId) async {
    final record = await _backend.findProfileBySourceId(userId) ??
        await _backend.getOne('profiles', userId);
    return _profileFromRecord(record);
  }

  Future<void> updateProfile(
    String userId, {
    String? fullName,
    String? role,
  }) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (role != null) updates['role'] = role;

    if (updates.isEmpty) return;

    final record = await _backend.findProfileBySourceId(userId);
    await _backend.update('profiles', record?.id ?? userId, updates);
  }

  Future<void> updatePassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    final record = await _backend.findProfileBySourceId(userId);
    await _backend.update(
      'profiles',
      record?.id ?? userId,
      {
        'oldPassword': oldPassword,
        'password': newPassword,
        'passwordConfirm': newPassword,
      },
    );
  }

  Profile _profileFromRecord(RecordModel record) {
    return Profile.fromJson({
      'id': record.get<String?>('source_id') ?? record.id,
      'full_name': record.get<String?>('full_name'),
      'role': record.get<String?>('role') ?? 'teacher',
      'updated_at':
          record.get<String?>('updated_at') ?? record.get<String?>('updated'),
    });
  }

  String _newProfileRecordId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final random = Random.secure().nextInt(1 << 32).toRadixString(36);
    return '$timestamp$random'.padRight(15, '0').substring(0, 15);
  }
}
