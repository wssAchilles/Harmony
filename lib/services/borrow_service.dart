import '../utils/app_logger.dart';
import 'package:pocketbase/pocketbase.dart';

import '../models/book.dart';
import '../models/borrow_record.dart';
import '../models/student.dart';
import 'app_exception.dart';
import 'auth_service.dart';
import 'backend/backend_gateway.dart';
import 'backend/pb_mapper.dart';

/// 借阅服务层
class BorrowService {
  static final BorrowService _instance = BorrowService._internal();
  factory BorrowService() => _instance;
  BorrowService._internal({BackendGateway? backend})
      : _backend = backend ?? backendGateway;

  BorrowService.withBackend(BackendGateway backend) : _backend = backend;

  final BackendGateway _backend;

  Future<void> borrowBookToStudent({
    required Book book,
    required Student student,
    int quantity = 1,
    int borrowDays = 14,
  }) async {
    if (student.id == null) {
      throw const InvalidRequestException('学生ID不能为空');
    }
    await _borrowBook(
      book: book,
      quantity: quantity,
      borrowDays: borrowDays,
      studentId: student.id,
    );
  }

  Future<void> borrowBookToTeacher({
    required Book book,
    int quantity = 1,
    int borrowDays = 30,
  }) async {
    await _borrowBook(
      book: book,
      quantity: quantity,
      borrowDays: borrowDays,
      profileId: AuthService().currentUserId,
    );
  }

  Future<void> _borrowBook({
    required Book book,
    required int quantity,
    required int borrowDays,
    int? studentId,
    String? profileId,
  }) async {
    if (quantity <= 0) {
      throw const InvalidBorrowQuantityException();
    }

    final currentUserId = AuthService().currentUserId;
    if (currentUserId == null) {
      throw const UnauthenticatedException();
    }

    final bookRecord = await _backend.findByNumericId('books', book.id!);
    if (bookRecord == null) {
      throw RecordNotFoundException('books', book.id!);
    }

    final available = asInt(bookRecord.get('available_quantity'));
    if (available < quantity) {
      throw InsufficientStockException(
        available: available,
        requested: quantity,
      );
    }

    final now = DateTime.now();
    await _backend.update(
      'books',
      bookRecord.id,
      {
        'available_quantity': available - quantity,
        'last_updated_by': currentUserId,
        'status': available - quantity > 0 ? 'available' : 'borrowed',
      },
    );

    try {
      await _backend.create(
        'borrow_records',
        {
          'id': numericRecordId(await _backend.nextNumericId('borrow_records')),
          'created_at': now.toUtc().toIso8601String(),
          'book_id': book.id,
          'student_id': studentId,
          'profile_id': profileId,
          'borrow_date': dateForPocketBase(now),
          'due_date': dateForPocketBase(
            now.add(Duration(days: borrowDays)),
          ),
          'borrowed_by_user_id': currentUserId,
          'quantity': quantity,
        },
      );
    } catch (e) {
      await _backend.update(
        'books',
        bookRecord.id,
        {
          'available_quantity': available,
          'last_updated_by': currentUserId,
          'status': book.status,
        },
      );
      rethrow;
    }
  }

  Future<void> returnBook(int recordId) async {
    try {
      final currentUserId = AuthService().currentUserId;
      if (currentUserId == null) {
        throw const UnauthenticatedException();
      }

      final record = await _backend.findByNumericId('borrow_records', recordId);
      if (record == null) {
        throw RecordNotFoundException('borrow_records', recordId);
      }

      if (asNullableDate(record.get('return_date')) != null) {
        throw const BorrowRecordAlreadyReturnedException();
      }

      final bookId = asInt(record.get('book_id'));
      final bookRecord = await _backend.findByNumericId('books', bookId);
      if (bookRecord == null) {
        throw RecordNotFoundException('books', bookId);
      }

      final currentAvailable = asInt(bookRecord.get('available_quantity'));
      final totalQuantity = asInt(bookRecord.get('total_quantity'));
      final returnQuantity = asInt(record.get('quantity'), fallback: 1);
      final nextAvailable = (currentAvailable + returnQuantity).clamp(
        0,
        totalQuantity,
      );

      await _backend.update(
        'borrow_records',
        record.id,
        {'return_date': dateForPocketBase(DateTime.now())},
      );

      await _backend.update(
        'books',
        bookRecord.id,
        {
          'available_quantity': nextAvailable,
          'last_updated_by': currentUserId,
          'status': nextAvailable > 0 ? 'available' : 'borrowed',
        },
      );
    } catch (e) {
      AppLogger.warning('归还图书失败: $e');
      rethrow;
    }
  }

  Future<void> returnBookByBook({required Book book}) async {
    final record = await _firstBorrowRecord(
      'book_id = ${book.id} && return_date = null',
    );
    if (record == null) {
      throw Exception('未找到该图书的借阅记录');
    }
    await returnBook(asInt(recordToJson(record)['id']));
  }

  Future<BorrowRecord?> getCurrentBorrowRecord(int bookId) async {
    try {
      final record = await _firstBorrowRecord(
        'book_id = $bookId && return_date = null',
      );
      if (record == null) return null;
      return _borrowRecordFromRecord(record);
    } catch (e) {
      AppLogger.warning('获取借阅记录失败: $e');
      return null;
    }
  }

  Future<List<BorrowRecord>> getStudentBorrowHistory(int studentId) async {
    try {
      return _loadBorrowRecords(
        filter: 'student_id = $studentId',
        sort: '-borrow_date',
      );
    } catch (e) {
      AppLogger.warning('获取学生借阅历史失败: $e');
      return [];
    }
  }

  Future<List<BorrowRecord>> getTeacherBorrowHistory(String teacherId) async {
    try {
      return _loadBorrowRecords(
        filter: 'profile_id = "${escapeFilterValue(teacherId)}"',
        sort: '-borrow_date',
      );
    } catch (e) {
      AppLogger.warning('获取老师借阅历史失败: $e');
      return [];
    }
  }

  Stream<List<BorrowRecord>> getActiveBorrowsStream() {
    return _backend.pollingListStream(() {
      return _loadBorrowRecords(filter: 'return_date = null', sort: 'due_date');
    });
  }

  Future<List<BorrowRecord>> getOverdueRecords() async {
    try {
      return _loadBorrowRecords(
        filter:
            'return_date = null && due_date < "${DateTime.now().toUtc().toIso8601String()}"',
        sort: 'due_date',
      );
    } catch (e) {
      AppLogger.warning('获取逾期记录失败: $e');
      return [];
    }
  }

  Future<void> renewBorrow({
    required BorrowRecord record,
    int extraDays = 7,
  }) async {
    if (record.isReturned) {
      throw Exception('该图书已归还，无需续借');
    }

    try {
      final recordId = await _backend.requireRecordIdByNumericId(
        'borrow_records',
        record.id,
      );
      final newDueDate = record.dueDate?.add(Duration(days: extraDays)) ??
          DateTime.now().add(Duration(days: extraDays));

      await _backend.update(
        'borrow_records',
        recordId,
        {'due_date': dateForPocketBase(newDueDate)},
      );
    } catch (e) {
      AppLogger.warning('续借失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getBorrowStatistics() async {
    try {
      final allRecords = await _loadBorrowRecords(sort: '-borrow_date');
      final activeRecords =
          allRecords.where((record) => !record.isReturned).toList();
      final overdueRecords =
          activeRecords.where((record) => record.isOverdue).toList();

      return {
        'total_borrows': allRecords.length,
        'active_borrows': activeRecords.length,
        'overdue_borrows': overdueRecords.length,
      };
    } catch (e) {
      AppLogger.warning('获取统计信息失败: $e');
      return {'total_borrows': 0, 'active_borrows': 0, 'overdue_borrows': 0};
    }
  }

  Future<List<BorrowRecord>> getActiveBorrowRecords() {
    return _loadBorrowRecords(
      filter: 'return_date = null',
      sort: '-borrow_date',
    );
  }

  Future<List<BorrowRecord>> getActiveBorrowRecordsForBook(int bookId) {
    return _loadBorrowRecords(
      filter: 'book_id = $bookId && return_date = null',
      sort: '-borrow_date',
    );
  }

  Future<List<BorrowRecord>> getAllBorrowRecords() {
    return _loadBorrowRecords(sort: '-borrow_date');
  }

  Future<List<BorrowRecord>> _loadBorrowRecords({
    String? filter,
    String? sort,
  }) async {
    final records = await _backend.getFullList(
      'borrow_records',
      filter: filter,
      sort: sort,
    );
    return Future.wait(records.map(_borrowRecordFromRecord));
  }

  Future<RecordModel?> _firstBorrowRecord(String filter) async {
    final result = await _backend.getList(
      'borrow_records',
      page: 1,
      perPage: 1,
      filter: filter,
      sort: '-borrow_date',
    );
    return result.items.isEmpty ? null : result.items.first;
  }

  Future<BorrowRecord> _borrowRecordFromRecord(RecordModel record) async {
    final data = recordToJson(record);
    final bookId = asNullableInt(data['book_id']);
    final studentId = asNullableInt(data['student_id']);
    final profileId = asNullableString(data['profile_id']);
    final handlerId = asNullableString(data['borrowed_by_user_id']);

    if (bookId != null) {
      final book = await _findBook(bookId);
      if (book != null) {
        data['book_title'] = book.title;
        data['book_author'] = book.author;
        data['book_cover_image_url'] = book.coverImageUrl;
      }
    }

    if (studentId != null) {
      final student = await _findStudent(studentId);
      if (student != null) {
        data['student_name'] = student.fullName;
      }
    }

    if (profileId != null) {
      data['teacher_name'] = await _findUserName(profileId);
      data['borrower_teacher_name'] = data['teacher_name'];
    }

    if (handlerId != null) {
      data['handler_teacher_name'] = await _findUserName(handlerId);
    }

    return BorrowRecord.fromJson(data);
  }

  Future<Book?> _findBook(int id) async {
    final record = await _backend.findByNumericId('books', id);
    return record == null ? null : Book.fromJson(recordToJson(record));
  }

  Future<Student?> _findStudent(int id) async {
    final record = await _backend.findByNumericId('students', id);
    return record == null ? null : Student.fromJson(recordToJson(record));
  }

  Future<String?> _findUserName(String id) async {
    try {
      final profile = await AuthService().getUserProfileById(id);
      return profile?.fullName;
    } catch (_) {
      return null;
    }
  }
}
