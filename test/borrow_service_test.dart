import 'package:flutter_test/flutter_test.dart';
import 'package:kindergarten_library/models/book.dart';
import 'package:kindergarten_library/models/student.dart';
import 'package:kindergarten_library/services/app_exception.dart';
import 'package:kindergarten_library/services/backend/backend_gateway.dart';
import 'package:kindergarten_library/services/backend/pb_mapper.dart';
import 'package:kindergarten_library/services/borrow_service.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  test('teacher can borrow a book on behalf of a student', () async {
    final backend = _FakeBackendGateway()
      ..putRecord('books', _bookRecord(id: 1, availableQuantity: 3))
      ..putRecord('students', _studentRecord(id: 2));
    final service = BorrowService.withBackend(
      backend,
      currentUserIdProvider: () => 'teacher-1',
    );

    await service.borrowBookToStudent(
      book: Book(id: 1, title: '小熊绘本'),
      student: Student(id: 2, fullName: '小明', className: '大班A'),
      quantity: 2,
      borrowDays: 7,
    );

    final book = backend.record('books', 1);
    expect(book.get<int>('available_quantity'), 1);
    expect(book.get<String>('last_updated_by'), 'teacher-1');
    expect(book.get<String>('status'), 'available');

    final record = backend.records('borrow_records').single;
    expect(record.get<int>('book_id'), 1);
    expect(record.get<int>('student_id'), 2);
    expect(record.get<String>('borrowed_by_user_id'), 'teacher-1');
    expect(record.get<int>('quantity'), 2);
    expect(record.get<String>('due_date'), isNotEmpty);
  });

  test('borrowing more than available stock fails without changing inventory',
      () async {
    final backend = _FakeBackendGateway()
      ..putRecord('books', _bookRecord(id: 1, availableQuantity: 1))
      ..putRecord('students', _studentRecord(id: 2));
    final service = BorrowService.withBackend(
      backend,
      currentUserIdProvider: () => 'teacher-1',
    );

    await expectLater(
      service.borrowBookToStudent(
        book: Book(id: 1, title: '小熊绘本'),
        student: Student(id: 2, fullName: '小明'),
        quantity: 2,
      ),
      throwsA(isA<InsufficientStockException>()),
    );

    expect(backend.record('books', 1).get<int>('available_quantity'), 1);
    expect(backend.records('borrow_records'), isEmpty);
  });

  test('returning a borrowed book writes return date and restores stock',
      () async {
    final backend = _FakeBackendGateway()
      ..putRecord('books', _bookRecord(id: 1, availableQuantity: 2))
      ..putRecord('students', _studentRecord(id: 2));
    final service = BorrowService.withBackend(
      backend,
      currentUserIdProvider: () => 'teacher-1',
    );

    await service.borrowBookToStudent(
      book: Book(id: 1, title: '小熊绘本'),
      student: Student(id: 2, fullName: '小明'),
      quantity: 2,
    );
    final recordId = asInt(backend.records('borrow_records').single.id);

    await service.returnBook(recordId);

    final record = backend.record('borrow_records', recordId);
    expect(record.get<String>('return_date'), isNotEmpty);
    expect(backend.record('books', 1).get<int>('available_quantity'), 2);
    expect(backend.record('books', 1).get<String>('status'), 'available');
  });

  test('getDueSoonRecords returns active records due within three days',
      () async {
    final now = DateTime.now();
    final backend = _FakeBackendGateway()
      ..putRecord('books', _bookRecord(id: 1, availableQuantity: 2))
      ..putRecord('students', _studentRecord(id: 2))
      ..putRecord(
        'borrow_records',
        _borrowRecord(
          id: 1,
          dueDate: now.add(const Duration(days: 2)),
        ),
      )
      ..putRecord(
        'borrow_records',
        _borrowRecord(
          id: 2,
          dueDate: now.add(const Duration(days: 5)),
        ),
      )
      ..putRecord(
        'borrow_records',
        _borrowRecord(
          id: 3,
          dueDate: now.subtract(const Duration(days: 1)),
        ),
      )
      ..putRecord(
        'borrow_records',
        _borrowRecord(
          id: 4,
          dueDate: now.add(const Duration(days: 1)),
          returnDate: now,
        ),
      )
      ..putRecord(
        'borrow_records',
        _borrowRecord(
          id: 5,
          dueDate: now.add(const Duration(days: 3, hours: 1)),
        ),
      );
    final service = BorrowService.withBackend(
      backend,
      currentUserIdProvider: () => 'teacher-1',
    );

    final records = await service.getDueSoonRecords();

    expect(records.map((record) => record.id), [1]);
  });
}

RecordModel _bookRecord({
  required int id,
  required int availableQuantity,
  int totalQuantity = 4,
}) {
  return RecordModel({
    'id': numericRecordId(id),
    'created_at': DateTime(2026).toUtc().toIso8601String(),
    'title': '小熊绘本',
    'author': '张老师',
    'location': 'A架1层',
    'cover_image_url': '',
    'status': availableQuantity > 0 ? 'available' : 'borrowed',
    'total_quantity': totalQuantity,
    'available_quantity': availableQuantity,
    'category_id': null,
  });
}

RecordModel _studentRecord({required int id}) {
  return RecordModel({
    'id': numericRecordId(id),
    'created_at': DateTime(2026).toUtc().toIso8601String(),
    'full_name': '小明',
    'class_name': '大班A',
  });
}

RecordModel _borrowRecord({
  required int id,
  required DateTime dueDate,
  DateTime? returnDate,
}) {
  return RecordModel({
    'id': numericRecordId(id),
    'created_at': DateTime(2026).toUtc().toIso8601String(),
    'book_id': 1,
    'student_id': 2,
    'profile_id': null,
    'borrow_date': DateTime(2026).toUtc().toIso8601String(),
    'due_date': dueDate.toUtc().toIso8601String(),
    'return_date': returnDate?.toUtc().toIso8601String(),
    'borrowed_by_user_id': 'teacher-1',
    'quantity': 1,
  });
}

class _FakeBackendGateway implements BackendGateway {
  final Map<String, Map<String, RecordModel>> _store = {};

  void putRecord(String collection, RecordModel record) {
    _store.putIfAbsent(collection, () => {})[record.id] = record;
  }

  RecordModel record(String collection, int numericId) {
    return _store[collection]![numericRecordId(numericId)]!;
  }

  List<RecordModel> records(String collection) {
    return _store[collection]?.values.toList() ?? [];
  }

  @override
  Future<RecordModel> create(String collection, Map<String, dynamic> body) async {
    final record = RecordModel(Map<String, dynamic>.from(body));
    putRecord(collection, record);
    return record;
  }

  @override
  Future<RecordModel?> findByNumericId(String collection, int id) async {
    return _store[collection]?[numericRecordId(id)];
  }

  @override
  Future<List<RecordModel>> getFullList(
    String collection, {
    String? filter,
    String? sort,
    String? fields,
  }) async {
    final result = records(collection).where((record) {
      if (filter == null || filter.isEmpty) return true;
      return _matchesFilter(record, filter);
    }).toList();
    if (sort == 'due_date') {
      result.sort((a, b) => _date(a, 'due_date').compareTo(_date(b, 'due_date')));
    } else if (sort == '-borrow_date') {
      result
          .sort((a, b) => _date(b, 'borrow_date').compareTo(_date(a, 'borrow_date')));
    }
    return result;
  }

  @override
  Future<ResultList<RecordModel>> getList(
    String collection, {
    int page = 1,
    int perPage = 30,
    String? filter,
    String? sort,
    String? fields,
  }) async {
    final items = await getFullList(collection, filter: filter, sort: sort);
    return ResultList<RecordModel>(
      page: page,
      perPage: perPage,
      totalItems: items.length,
      totalPages: 1,
      items: items.take(perPage).toList(),
    );
  }

  @override
  Future<int> nextNumericId(String collection) async {
    final ids = records(collection)
        .map((record) => asInt(record.id))
        .where((id) => id > 0)
        .toList();
    if (ids.isEmpty) return 1;
    return ids.reduce((a, b) => a > b ? a : b) + 1;
  }

  @override
  Future<String> requireRecordIdByNumericId(String collection, int id) async {
    final record = await findByNumericId(collection, id);
    if (record == null) throw RecordNotFoundException(collection, id);
    return record.id;
  }

  @override
  Future<RecordModel> update(
    String collection,
    String id,
    Map<String, dynamic> body,
  ) async {
    final record = _store[collection]![id]!;
    record.data.addAll(body);
    return record;
  }

  bool _matchesFilter(RecordModel record, String filter) {
    if (filter.contains('return_date = null') &&
        record.data['return_date'] != null) {
      return false;
    }
    if (filter.contains('student_id =')) {
      final expected = int.parse(filter.split('student_id =').last.trim());
      if (record.get<int?>('student_id') != expected) return false;
    }
    if (filter.contains('book_id =')) {
      final expected = int.parse(
        filter.split('book_id =').last.split('&&').first.trim(),
      );
      if (record.get<int?>('book_id') != expected) return false;
    }
    if (filter.contains('due_date >=')) {
      final lower = _quotedDate(filter, 'due_date >=');
      if (_date(record, 'due_date').isBefore(lower)) return false;
    }
    if (filter.contains('due_date <')) {
      final upper = _quotedDate(filter, 'due_date <');
      if (!_date(record, 'due_date').isBefore(upper)) return false;
    }
    return true;
  }

  DateTime _date(RecordModel record, String field) {
    return DateTime.parse(record.get<String>(field));
  }

  DateTime _quotedDate(String filter, String prefix) {
    final afterPrefix = filter.split(prefix).last;
    final value = afterPrefix.split('"')[1];
    return DateTime.parse(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
