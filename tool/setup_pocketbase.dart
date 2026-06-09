import 'dart:io';

import 'package:pocketbase/pocketbase.dart';

const _defaultUrl = 'http://127.0.0.1:8090';
const _defaultEmail = 'admin@example.com';
const _defaultPassword = 'admin123456';
const _backupPath =
    'supabase_restore_work/db_cluster-16-09-2025@15-17-22.backup';
const _importPassword = 'PocketBase123456';

Future<void> main() async {
  final url = Platform.environment['POCKETBASE_URL'] ?? _defaultUrl;
  final email = Platform.environment['PB_ADMIN_EMAIL'] ?? _defaultEmail;
  final password =
      Platform.environment['PB_ADMIN_PASSWORD'] ?? _defaultPassword;

  final pb = PocketBase(url);
  await pb.collection('_superusers').authWithPassword(email, password);

  final dump = await File(_backupPath).readAsString();
  final tables = {
    'auth.users': _readCopyTable(dump, 'auth.users'),
    'public.profiles': _readCopyTable(dump, 'public.profiles'),
    'public.categories': _readCopyTable(dump, 'public.categories'),
    'public.students': _readCopyTable(dump, 'public.students'),
    'public.books': _readCopyTable(dump, 'public.books'),
    'public.borrow_records': _readCopyTable(dump, 'public.borrow_records'),
  };

  await _resetCollections(pb);
  await _createCollections(pb);
  await _importData(pb, tables);

  stdout.writeln('PocketBase schema and data are ready at $url');
  stdout.writeln('Migrated rows:');
  for (final entry in tables.entries) {
    stdout.writeln('- ${entry.key}: ${entry.value.rows.length}');
  }
  stdout.writeln('Imported profile login password: $_importPassword');
}

Future<void> _resetCollections(PocketBase pb) async {
  const names = [
    'record_id_probe',
    'id_field_probe',
    'book_cover_files',
    'borrow_records',
    'books',
    'students',
    'categories',
    'users',
    'profiles',
  ];
  for (final name in names) {
    try {
      await pb.collections.delete(name);
      stdout.writeln('Deleted collection: $name');
    } catch (_) {}
  }
}

Future<void> _createCollections(PocketBase pb) async {
  await pb.collections.create(
    body: {
      'name': 'profiles',
      'type': 'auth',
      'listRule': '@request.auth.id != ""',
      'viewRule': '@request.auth.id != ""',
      'createRule': '',
      'updateRule': '@request.auth.id = id || @request.auth.role = "admin"',
      'deleteRule': '@request.auth.role = "admin"',
      'authRule': '',
      'fields': [
        _text('source_id', required: true, max: 64),
        _text('full_name'),
        _date('updated_at'),
        _text('role', required: true),
      ],
      'indexes': [
        'CREATE UNIQUE INDEX `idx_profiles_source_id` ON `profiles` (`source_id`)',
      ],
      'passwordAuth': {
        'enabled': true,
        'identityFields': ['email'],
      },
    },
  );

  await _createBaseCollection(pb, 'categories', [
    _text('name', required: true),
    _date('created_at', required: true),
  ]);

  await _createBaseCollection(pb, 'students', [
    _date('created_at', required: true),
    _text('full_name', required: true),
    _text('class_name'),
  ]);

  await _createBaseCollection(
    pb,
    'books',
    [
      _date('created_at', required: true),
      _text('title', required: true),
      _text('author'),
      _text('publisher'),
      _text('isbn'),
      _text('location'),
      _text('cover_image_url'),
      _text('status', required: true),
      _text('last_updated_by'),
      _number('total_quantity', required: true, onlyInt: true, min: 0),
      _number('available_quantity', required: true, onlyInt: true, min: 0),
      _json('category_id'),
      _json('tags'),
      _number('rating', min: 0, max: 5),
    ],
    indexes: [
      'CREATE INDEX `idx_books_category_id` ON `books` (`category_id`)',
      'CREATE INDEX `idx_books_isbn` ON `books` (`isbn`)',
    ],
  );

  await _createBaseCollection(
    pb,
    'borrow_records',
    [
      _date('created_at', required: true),
      _number('book_id', required: true, onlyInt: true),
      _json('student_id'),
      _text('profile_id'),
      _date('borrow_date', required: true),
      _date('due_date'),
      _date('return_date'),
      _text('borrowed_by_user_id', required: true),
      _number('quantity', required: true, onlyInt: true, min: 1),
    ],
    indexes: [
      'CREATE INDEX `idx_borrow_records_book_id` ON `borrow_records` (`book_id`)',
      'CREATE INDEX `idx_borrow_records_student_id` ON `borrow_records` (`student_id`)',
      'CREATE INDEX `idx_borrow_records_profile_id` ON `borrow_records` (`profile_id`)',
      'CREATE INDEX `idx_borrow_records_return_date` ON `borrow_records` (`return_date`)',
    ],
  );
}

Future<void> _createBaseCollection(
  PocketBase pb,
  String name,
  List<Map<String, Object?>> fields, {
  List<String> indexes = const [],
}) async {
  await pb.collections.create(
    body: {
      'name': name,
      'type': 'base',
      'listRule': '@request.auth.id != ""',
      'viewRule': '@request.auth.id != ""',
      'createRule': '@request.auth.id != ""',
      'updateRule': '@request.auth.id != ""',
      'deleteRule': '@request.auth.id != ""',
      'fields': fields,
      'indexes': indexes,
    },
  );
}

Future<void> _importData(PocketBase pb, Map<String, CopyTable> tables) async {
  final authUsers = {
    for (final row in tables['auth.users']!.rows) row['id']!: row,
  };

  for (final row in tables['public.profiles']!.rows) {
    final sourceId = row['id']!;
    final user = authUsers[sourceId];
    await pb.collection('profiles').create(
      body: {
        'id': _idFromUuid(sourceId),
        'email': user?['email'] ?? '${_idFromUuid(sourceId)}@local.invalid',
        'password': _importPassword,
        'passwordConfirm': _importPassword,
        'emailVisibility': true,
        'verified': true,
        'source_id': sourceId,
        'full_name': row['full_name'],
        'updated_at': _dateValue(row['updated_at']),
        'role': row['role'] ?? 'teacher',
      },
    );
  }

  for (final row in tables['public.categories']!.rows) {
    await pb.collection('categories').create(
      body: {
        'id': _numericRecordId(row['id']!),
        'name': row['name'],
        'created_at': _dateValue(row['created_at']),
      },
    );
  }

  for (final row in tables['public.students']!.rows) {
    await pb.collection('students').create(
      body: {
        'id': _numericRecordId(row['id']!),
        'created_at': _dateValue(row['created_at']),
        'full_name': row['full_name'],
        'class_name': row['class_name'],
      },
    );
  }

  for (final row in tables['public.books']!.rows) {
    await pb.collection('books').create(
      body: {
        'id': _numericRecordId(row['id']!),
        'created_at': _dateValue(row['created_at']),
        'title': row['title'],
        'author': row['author'],
        'publisher': null,
        'isbn': null,
        'location': row['location'],
        'cover_image_url': row['cover_image_url'],
        'status': row['status'],
        'last_updated_by': row['last_updated_by'],
        'total_quantity': _intValue(row['total_quantity']),
        'available_quantity': _intValue(row['available_quantity']),
        'category_id': _intValue(row['category_id']),
        'tags': <String>[],
        'rating': null,
      },
    );
  }

  for (final row in tables['public.borrow_records']!.rows) {
    await pb.collection('borrow_records').create(
      body: {
        'id': _numericRecordId(row['id']!),
        'created_at': _dateValue(row['created_at']),
        'book_id': _intValue(row['book_id']),
        'student_id': _intValue(row['student_id']),
        'profile_id': row['profile_id'],
        'borrow_date': _dateValue(row['borrow_date']),
        'due_date': _dateValue(row['due_date']),
        'return_date': _dateValue(row['return_date']),
        'borrowed_by_user_id': row['borrowed_by_user_id'],
        'quantity': _intValue(row['quantity']) ?? 1,
      },
    );
  }
}

CopyTable _readCopyTable(String dump, String tableName) {
  final pattern = RegExp(
    r'^COPY ' +
        RegExp.escape(tableName) +
        r' \(([^)]+)\) FROM stdin;\n([\s\S]*?)\n\\\.$',
    multiLine: true,
  );
  final match = pattern.firstMatch(dump);
  if (match == null) {
    throw StateError('COPY block not found: $tableName');
  }

  final columns =
      match.group(1)!.split(',').map((column) => column.trim()).toList();
  final rows = <Map<String, String?>>[];
  final body = match.group(2)!;
  for (final line in body.split('\n')) {
    if (line.trim().isEmpty) continue;
    final values = line.split('\t');
    rows.add({
      for (var i = 0; i < columns.length; i++)
        columns[i]: values[i] == r'\N' ? null : values[i],
    });
  }
  return CopyTable(columns, rows);
}

String _numericRecordId(String value) {
  return value.padLeft(15, '0');
}

String _idFromUuid(String uuid) {
  return uuid.replaceAll('-', '').substring(0, 15).toLowerCase();
}

String? _dateValue(String? value) {
  if (value == null) return null;
  return DateTime.parse(value.replaceFirst(' ', 'T')).toUtc().toIso8601String();
}

int? _intValue(String? value) {
  if (value == null) return null;
  return int.tryParse(value);
}

Map<String, Object?> _text(String name, {bool required = false, int max = 0}) {
  return {'name': name, 'type': 'text', 'required': required, 'max': max};
}

Map<String, Object?> _number(
  String name, {
  bool required = false,
  bool onlyInt = false,
  num? min,
  num? max,
}) {
  return {
    'name': name,
    'type': 'number',
    'required': required,
    'onlyInt': onlyInt,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
  };
}

Map<String, Object?> _date(String name, {bool required = false}) {
  return {'name': name, 'type': 'date', 'required': required};
}

Map<String, Object?> _json(String name, {bool required = false}) {
  return {'name': name, 'type': 'json', 'required': required};
}

class CopyTable {
  CopyTable(this.columns, this.rows);

  final List<String> columns;
  final List<Map<String, String?>> rows;
}
