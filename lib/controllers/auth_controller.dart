import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/profile.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({AuthService? authService, Stream<bool>? authStateChanges})
      : _authService = authService ?? AuthService() {
    _authSubscription =
        (authStateChanges ?? _authService.authStateChanges).listen((_) {
      _syncAuthState();
    });
  }

  final AuthService _authService;
  late final StreamSubscription<bool> _authSubscription;

  bool _isInitializing = true;
  bool _isRefreshingProfile = false;
  bool _isDisposed = false;
  String? _errorMessage;

  bool get isInitializing => _isInitializing;
  bool get isRefreshingProfile => _isRefreshingProfile;
  String? get errorMessage => _errorMessage;

  Profile? get currentProfile => _authService.currentProfile;
  String? get currentUserId => _authService.currentUserId;
  String? get currentUserEmail => _authService.currentUserEmail;
  bool get isLoggedIn => _authService.isLoggedIn;
  bool get isAdmin => _authService.isAdmin;
  bool get isTeacher => _authService.isTeacher;
  String get displayName => _authService.displayName;
  String get roleDisplayName => _authService.roleDisplayName;

  Future<void> initialize() async {
    _isInitializing = true;
    _errorMessage = null;
    _notifyIfActive();

    try {
      await _authService.initializeUserState();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (!_isDisposed) {
        _isInitializing = false;
        _notifyIfActive();
      }
    }
  }

  Future<void> refreshProfile() async {
    _isRefreshingProfile = true;
    _errorMessage = null;
    _notifyIfActive();

    try {
      await _authService.refreshCurrentProfile();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (!_isDisposed) {
        _isRefreshingProfile = false;
        _notifyIfActive();
      }
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _notifyIfActive();
  }

  Future<void> signIn({required String email, required String password}) async {
    await _authService.signIn(email: email, password: password);
    _notifyIfActive();
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await _authService.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );
    _notifyIfActive();
  }

  Future<void> updateProfile({String? fullName, String? role}) async {
    await _authService.updateProfile(fullName: fullName, role: role);
    _notifyIfActive();
  }

  Future<void> _syncAuthState() async {
    if (_authService.isLoggedIn) {
      await _authService.initializeUserState();
    } else {
      _authService.onUserLoggedOut();
    }

    if (_isDisposed) return;
    _isInitializing = false;
    _notifyIfActive();
  }

  void _notifyIfActive() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _authSubscription.cancel();
    super.dispose();
  }
}
