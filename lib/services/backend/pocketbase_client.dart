import 'package:flutter/services.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/backend_config.dart';

const _authStoreKey = 'pb_auth';

late final PocketBase pb;

Future<void> initializePocketBase() async {
  pb = PocketBase(
    BackendConfig.pocketBaseUrl,
    authStore: await _createAuthStore(),
    reuseHTTPClient: true,
  );
}

Future<AuthStore> _createAuthStore() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return AsyncAuthStore(
      save: (String data) async => prefs.setString(_authStoreKey, data),
      initial: prefs.getString(_authStoreKey),
    );
  } on MissingPluginException {
    return _createMemoryAuthStore();
  } catch (error) {
    if (_isMissingSharedPreferencesPlugin(error)) {
      return _createMemoryAuthStore();
    }
    rethrow;
  }
}

AuthStore _createMemoryAuthStore() {
  return AsyncAuthStore(save: (_) async {});
}

bool _isMissingSharedPreferencesPlugin(Object error) {
  final message = error.toString();
  return message.contains('MissingPluginException') &&
      message.contains('plugins.flutter.io/shared_preferences');
}
