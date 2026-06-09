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
    stderr.writeln('Usage: dart run tool/patch_pocketbase_schema.dart [--dry-run]');
    exitCode = 64;
    return;
  }

  final url = Platform.environment['POCKETBASE_URL'] ?? _defaultUrl;
  final email = Platform.environment['PB_ADMIN_EMAIL'] ?? _defaultEmail;
  final password =
      Platform.environment['PB_ADMIN_PASSWORD'] ?? _defaultPassword;

  final pb = PocketBase(url);
  await pb.collection('_superusers').authWithPassword(email, password);

  final books = await pb.collections.getOne('books');
  final fields = books.fields
      .map((field) => Map<String, dynamic>.from(field.toJson()))
      .toList();
  final existingFieldNames = fields
      .map((field) => field['name'])
      .whereType<String>()
      .toSet();
  final missingFields = _bookFields
      .where((field) => !existingFieldNames.contains(field['name']))
      .toList();

  final indexes = List<String>.from(books.indexes);
  final missingIndexes = <String>[];
  for (final index in _bookIndexes) {
    final indexName = _indexName(index);
    if (!indexes.any((existing) => _indexName(existing) == indexName)) {
      missingIndexes.add(index);
    }
  }

  if (missingFields.isEmpty && missingIndexes.isEmpty) {
    stdout.writeln('PocketBase books schema already has all required fields.');
    return;
  }

  stdout.writeln('PocketBase books schema patch plan:');
  for (final field in missingFields) {
    stdout.writeln('- add field: ${field['name']} (${field['type']})');
  }
  for (final index in missingIndexes) {
    stdout.writeln('- add index: ${_indexName(index)}');
  }

  if (dryRun) {
    stdout.writeln('Dry run only. No schema changes were written.');
    return;
  }

  await pb.collections.update(
    books.id,
    body: {
      'fields': [...fields, ...missingFields],
      'indexes': [...indexes, ...missingIndexes],
    },
  );

  stdout.writeln('PocketBase books schema patch complete.');
}

final _bookFields = <Map<String, dynamic>>[
  _text('publisher'),
  _text('isbn'),
  _json('tags'),
  _number('rating', min: 0, max: 5),
];

const _bookIndexes = [
  'CREATE INDEX `idx_books_isbn` ON `books` (`isbn`)',
];

Map<String, dynamic> _text(String name) {
  return {
    'name': name,
    'type': 'text',
    'required': false,
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

Map<String, dynamic> _number(String name, {num? min, num? max}) {
  return {
    'name': name,
    'type': 'number',
    'required': false,
    'onlyInt': false,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
  };
}

String _indexName(String sql) {
  final match = RegExp(r'INDEX\s+`([^`]+)`', caseSensitive: false)
      .firstMatch(sql);
  return match?.group(1) ?? sql;
}
