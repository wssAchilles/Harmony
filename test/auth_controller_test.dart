import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kindergarten_library/controllers/auth_controller.dart';
import 'package:kindergarten_library/models/profile.dart';
import 'package:kindergarten_library/services/auth_service.dart';

void main() {
  test('initialize failure exposes error and exits initializing state',
      () async {
    final authService = _FakeAuthService(initializeError: StateError('boom'));
    final controller = AuthController(
      authService: authService,
      authStateChanges: const Stream.empty(),
    );
    final states = <String>[];
    controller.addListener(() {
      states.add('${controller.isInitializing}:${controller.errorMessage}');
    });

    await controller.initialize();

    expect(controller.isInitializing, isFalse);
    expect(controller.errorMessage, contains('boom'));
    expect(states.first, 'true:null');
    expect(states.last, contains('false:Bad state: boom'));

    controller.dispose();
  });

  test('pending initialize does not notify after dispose', () async {
    final initializeCompleter = Completer<void>();
    final authService = _FakeAuthService(
      initializeCompleter: initializeCompleter,
    );
    final controller = AuthController(
      authService: authService,
      authStateChanges: const Stream.empty(),
    );

    final initializeFuture = controller.initialize();
    controller.dispose();
    initializeCompleter.complete();

    await initializeFuture;
  });

  test('auth stream events after dispose are ignored', () async {
    final authChanges = StreamController<bool>();
    final authService = _FakeAuthService();
    final controller = AuthController(
      authService: authService,
      authStateChanges: authChanges.stream,
    );

    controller.dispose();
    authChanges.add(true);
    await authChanges.close();
  });
}

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.initializeError, this.initializeCompleter});

  final Object? initializeError;
  final Completer<void>? initializeCompleter;

  @override
  Profile? currentProfile;

  @override
  String? currentUserEmail = 'teacher@example.com';

  @override
  String? currentUserId = 'teacher-id';

  @override
  bool isLoggedIn = false;

  @override
  bool get isAdmin => currentProfile?.isAdmin ?? false;

  @override
  bool get isTeacher => currentProfile?.isTeacher ?? true;

  @override
  Stream<bool> get authStateChanges => const Stream.empty();

  @override
  String get displayName => currentProfile?.fullName ?? '测试老师';

  @override
  String get roleDisplayName => isAdmin ? '超级管理员' : '普通老师';

  @override
  bool hasAdminAccess() => isLoggedIn && isAdmin;

  @override
  Future<void> initializeUserState() async {
    if (initializeCompleter != null) {
      await initializeCompleter!.future;
    }
    final error = initializeError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> onUserLoggedIn() => initializeUserState();

  @override
  void onUserLoggedOut() {
    currentProfile = null;
  }

  @override
  Future<void> refreshCurrentProfile() async {}

  @override
  Future<void> signIn({required String email, required String password}) async {
    isLoggedIn = true;
  }

  @override
  Future<void> signOut() async {
    isLoggedIn = false;
    onUserLoggedOut();
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    currentProfile = Profile(id: 'teacher-id', fullName: fullName);
    isLoggedIn = true;
  }

  @override
  Future<Profile?> getUserProfileById(String userId) async {
    return currentProfile;
  }

  @override
  Future<void> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> updateProfile({String? fullName, String? role}) async {
    currentProfile = Profile(
      id: currentUserId ?? 'teacher-id',
      fullName: fullName ?? currentProfile?.fullName,
      role: role ?? currentProfile?.role ?? 'teacher',
    );
  }
}
