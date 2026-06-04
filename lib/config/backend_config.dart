class BackendConfig {
  static const pocketBaseUrl = String.fromEnvironment(
    'POCKETBASE_URL',
    defaultValue: 'http://10.0.2.2:8090',
  );

  static String resolveFileUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final baseUrl = pocketBaseUrl.endsWith('/')
        ? pocketBaseUrl.substring(0, pocketBaseUrl.length - 1)
        : pocketBaseUrl;
    final path = value.startsWith('/') ? value : '/$value';
    return '$baseUrl$path';
  }
}
