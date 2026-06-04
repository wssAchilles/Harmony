import '../models/profile.dart';
import 'app_exception.dart';
import 'auth/auth_session.dart';
import 'auth/profile_repository.dart';

/// 全局认证和用户状态管理服务
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal()
      : _session = AuthSession(),
        _profiles = ProfileRepository();

  final AuthSession _session;
  final ProfileRepository _profiles;
  Profile? _currentProfile;
  String? _currentProfileUserId;
  Future<void>? _initializingUserState;

  Profile? get currentProfile => _currentProfile;

  String? get currentUserId => _session.currentUserId;

  String? get currentUserEmail => _session.currentUserEmail;

  bool get isLoggedIn => _session.isLoggedIn;

  bool get isAdmin => _currentProfile?.isAdmin ?? false;

  bool get isTeacher => _currentProfile?.isTeacher ?? true;

  Stream<bool> get authStateChanges {
    return _session.authStateChanges;
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
      await _profiles.refreshAuth();
    } catch (_) {
      _session.clear();
      _currentProfile = null;
      _currentProfileUserId = null;
      return;
    }

    await _loadUserProfile(userId);
  }

  Future<void> signIn({required String email, required String password}) async {
    await _profiles.signIn(email: email, password: password);
    await initializeUserState();
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await _profiles.createTeacherProfile(
      email: email,
      password: password,
      fullName: fullName,
    );
    await signIn(email: email, password: password);
  }

  Future<void> signOut() async {
    _session.clear();
    onUserLoggedOut();
  }

  Future<Profile?> getUserProfileById(String userId) async {
    return _profiles.getProfileByUserId(userId);
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
      await _profiles.updateProfile(
        currentUserId!,
        fullName: fullName,
        role: role,
      );
      await refreshCurrentProfile();
    } catch (e) {
      throwServiceException('更新用户资料失败', e);
    }
  }

  Future<void> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (currentUserId == null) return;

    await _profiles.updatePassword(
      userId: currentUserId!,
      oldPassword: oldPassword,
      newPassword: newPassword,
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
}
