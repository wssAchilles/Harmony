import '../backend/backend_gateway.dart';

class AuthSession {
  AuthSession({BackendGateway? backend}) : _backend = backend ?? backendGateway;

  final BackendGateway _backend;

  String? get currentUserId =>
      _backend.authRecord?.get<String?>('source_id') ?? _backend.authRecord?.id;

  String? get currentUserEmail => _backend.authRecord?.get<String?>('email');

  bool get isLoggedIn => _backend.isAuthValid;

  Stream<bool> get authStateChanges {
    return _backend.authChanges.map((_) => _backend.isAuthValid).distinct();
  }

  void clear() {
    _backend.clearAuth();
  }
}
