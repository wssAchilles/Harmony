import 'dart:math';

import 'package:pocketbase/pocketbase.dart';

import '../models/profile.dart';
import 'backend/pb_mapper.dart';
import 'backend/pocketbase_client.dart';

/// 全局认证和用户状态管理服务
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Profile? _currentProfile;
  String? _currentProfileUserId;
  Future<void>? _initializingUserState;

  Profile? get currentProfile => _currentProfile;

  String? get currentUserId =>
      pb.authStore.record?.get<String?>('source_id') ?? pb.authStore.record?.id;

  String? get currentUserEmail => pb.authStore.record?.get<String?>('email');

  bool get isLoggedIn => pb.authStore.isValid;

  bool get isAdmin => _currentProfile?.isAdmin ?? false;

  bool get isTeacher => _currentProfile?.isTeacher ?? true;

  Stream<bool> get authStateChanges {
    return pb.authStore.onChange.map((_) => pb.authStore.isValid).distinct();
  }

  Future<void> initializeUserState() async {
    final userId = currentUserId;
    if (!isLoggedIn || userId == null) {
      _currentProfile = null;
      _currentProfileUserId = null;
      return;
    }

    if (_currentProfile != null && _currentProfileUserId == userId) {
      return;
    }

    final pending = _initializingUserState;
    if (pending != null) {
      return pending;
    }

    _initializingUserState = _initializeUserState(userId);
    try {
      await _initializingUserState;
    } finally {
      _initializingUserState = null;
    }
  }

  Future<void> _initializeUserState(String userId) async {
    try {
      await pb.collection('profiles').authRefresh();
    } catch (_) {
      pb.authStore.clear();
      _currentProfile = null;
      _currentProfileUserId = null;
      return;
    }

    await _loadUserProfile(userId);
  }

  Future<void> signIn({required String email, required String password}) async {
    await pb.collection('profiles').authWithPassword(email, password);
    await initializeUserState();
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final profileId = _newProfileRecordId();
    await pb.collection('profiles').create(
      body: {
        'id': profileId,
        'source_id': profileId,
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'full_name': fullName,
        'role': 'teacher',
        'emailVisibility': true,
        'verified': true,
      },
    );
    await signIn(email: email, password: password);
  }

  Future<void> signOut() async {
    pb.authStore.clear();
    onUserLoggedOut();
  }

  Future<Profile?> getUserProfileById(String userId) async {
    final record = await findProfileBySourceId(userId) ??
        await pb.collection('profiles').getOne(userId);
    return _profileFromRecord(record);
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      _currentProfile = await getUserProfileById(userId);
      _currentProfileUserId = userId;
    } catch (e) {
      print('加载用户资料失败: $e');
      _currentProfile = null;
      _currentProfileUserId = null;
    }
  }

  Future<void> onUserLoggedIn() async {
    await initializeUserState();
  }

  void onUserLoggedOut() {
    _currentProfile = null;
    _currentProfileUserId = null;
  }

  Future<void> refreshCurrentProfile() async {
    if (currentUserId != null) {
      await _loadUserProfile(currentUserId!);
    }
  }

  Future<void> updateProfile({String? fullName, String? role}) async {
    if (currentUserId == null) return;

    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (role != null) updates['role'] = role;

    if (updates.isEmpty) return;

    try {
      final record = await findProfileBySourceId(currentUserId!);
      await pb
          .collection('profiles')
          .update(record?.id ?? currentUserId!, body: updates);
      await refreshCurrentProfile();
    } catch (e) {
      throw Exception('更新用户资料失败: $e');
    }
  }

  Future<void> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (currentUserId == null) return;

    final record = await findProfileBySourceId(currentUserId!);
    await pb.collection('profiles').update(
      record?.id ?? currentUserId!,
      body: {
        'oldPassword': oldPassword,
        'password': newPassword,
        'passwordConfirm': newPassword,
      },
    );
  }

  bool hasAdminAccess() {
    return isLoggedIn && isAdmin;
  }

  String get displayName {
    return _currentProfile?.fullName ??
        currentUserEmail?.split('@')[0] ??
        '未知用户';
  }

  String get roleDisplayName {
    switch (_currentProfile?.role) {
      case 'admin':
        return '超级管理员';
      case 'teacher':
        return '普通老师';
      default:
        return '未知角色';
    }
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
