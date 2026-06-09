import 'dart:io';

import 'package:pocketbase/pocketbase.dart';

const _defaultUrl = 'http://127.0.0.1:8090';
const _defaultEmail = 'admin@example.com';
const _defaultPassword = 'admin123456';

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final unknownArgs = args.where((arg) => arg != '--dry-run').toList();
  if (unknownArgs.isNotEmpty) {
    stderr.writeln('Unknown arguments: ${unknownArgs.join(', ')}');
    stderr.writeln(
        'Usage: dart run tool/patch_pocketbase_schema.dart [--dry-run]');
    exitCode = 64;
    return;
  }

  final url = Platform.environment['POCKETBASE_URL'] ?? _defaultUrl;
  final email = Platform.environment['PB_ADMIN_EMAIL'] ?? _defaultEmail;
  final password =
      Platform.environment['PB_ADMIN_PASSWORD'] ?? _defaultPassword;

  final pb = PocketBase(url);
  await pb.collection('_superusers').authWithPassword(email, password);

  final changed = <bool>[
    await _patchCollection(
      pb,
      name: 'books',
      fieldsToAdd: _bookFields,
      indexesToAdd: _bookIndexes,
      dryRun: dryRun,
    ),
    await _patchCollection(
      pb,
      name: 'borrow_records',
      fieldsToAdd: _borrowRecordFields,
      indexesToAdd: const [],
      dryRun: dryRun,
    ),
    await _ensureAppSettingsCollection(pb, dryRun: dryRun),
  ].any((value) => value);

  if (!changed) {
    stdout.writeln('PocketBase schema already has all required fields.');
  } else if (dryRun) {
    stdout.writeln('Dry run only. No schema changes were written.');
  } else {
    stdout.writeln('PocketBase schema patch complete.');
  }
}

final _bookFields = <Map<String, dynamic>>[
  _text('publisher'),
  _text('isbn'),
  _json('tags'),
  _number('rating', min: 0, max: 5),
];

final _borrowRecordFields = <Map<String, dynamic>>[
  _number('reminder_days_before', onlyInt: true, min: 1, max: 30),
];

const _bookIndexes = [
  'CREATE INDEX `idx_books_isbn` ON `books` (`isbn`)',
];

Future<bool> _patchCollection(
  PocketBase pb, {
  required String name,
  required List<Map<String, dynamic>> fieldsToAdd,
  required List<String> indexesToAdd,
  required bool dryRun,
}) async {
  final collection = await pb.collections.getOne(name);
  final fields = collection.fields
      .map((field) => Map<String, dynamic>.from(field.toJson()))
      .toList();
  final existingFieldNames =
      fields.map((field) => field['name']).whereType<String>().toSet();
  final missingFields = fieldsToAdd
      .where((field) => !existingFieldNames.contains(field['name']))
      .toList();

  final indexes = List<String>.from(collection.indexes);
  final missingIndexes = <String>[];
  for (final index in indexesToAdd) {
    final indexName = _indexName(index);
    if (!indexes.any((existing) => _indexName(existing) == indexName)) {
      missingIndexes.add(index);
    }
  }

  if (missingFields.isEmpty && missingIndexes.isEmpty) return false;

  stdout.writeln('PocketBase $name schema patch plan:');
  for (final field in missingFields) {
    stdout.writeln('- add field: ${field['name']} (${field['type']})');
  }
  for (final index in missingIndexes) {
    stdout.writeln('- add index: ${_indexName(index)}');
  }

  if (!dryRun) {
    await pb.collections.update(
      collection.id,
      body: {
        'fields': [...fields, ...missingFields],
        'indexes': [...indexes, ...missingIndexes],
      },
    );
  }

  return true;
}

Future<bool> _ensureAppSettingsCollection(
  PocketBase pb, {
  required bool dryRun,
}) async {
  try {
    return await _patchCollection(
      pb,
      name: 'app_settings',
      fieldsToAdd: _appSettingsFields,
      indexesToAdd: _appSettingsIndexes,
      dryRun: dryRun,
    );
  } on ClientException catch (error) {
    if (error.statusCode != 404) rethrow;
  }

  stdout.writeln('PocketBase app_settings schema patch plan:');
  stdout.writeln('- create collection: app_settings');
  if (dryRun) return true;

  await _createAppSettingsCollection(pb);
  return true;
}

Future<void> _createAppSettingsCollection(PocketBase pb) async {
  await pb.collections.create(
    body: {
      'name': 'app_settings',
      'type': 'base',
      'listRule': '@request.auth.id != ""',
      'viewRule': '@request.auth.id != ""',
      'createRule': '@request.auth.role = "admin"',
      'updateRule': '@request.auth.role = "admin"',
      'deleteRule': '@request.auth.role = "admin"',
      'fields': _appSettingsFields,
      'indexes': _appSettingsIndexes,
    },
  );
}

final _appSettingsFields = <Map<String, dynamic>>[
  _text('key', required: true),
  _json('value'),
  _date('updated_at'),
];

const _appSettingsIndexes = [
  'CREATE UNIQUE INDEX `idx_app_settings_key` ON `app_settings` (`key`)',
];

Map<String, dynamic> _text(String name, {bool required = false}) {
  return {
    'name': name,
    'type': 'text',
    'required': required,
    'max': 0,
  };
}

Map<String, dynamic> _json(String name) {
  return {
    'name': name,
    'type': 'json',
    'required': false,
  };
}

Map<String, dynamic> _number(
  String name, {
  num? min,
  num? max,
  bool onlyInt = false,
}) {
  return {
    'name': name,
    'type': 'number',
    'required': false,
    'onlyInt': onlyInt,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
  };
}

Map<String, dynamic> _date(String name) {
  return {
    'name': name,
    'type': 'date',
    'required': false,
  };
}

String _indexName(String sql) {
  final match =
      RegExp(r'INDEX\s+`([^`]+)`', caseSensitive: false).firstMatch(sql);
  return match?.group(1) ?? sql;
}
