import '../models/book.dart';
import '../models/borrow_record.dart';
import 'book_service.dart';
import 'borrow_service.dart';
import 'student_service.dart';

class DashboardService {
  final _bookService = BookService();
  final _borrowService = BorrowService();
  final _studentService = StudentService();
  Map<String, dynamic>? _lastSummary;
  List<Map<String, dynamic>>? _lastTopBooks;
  List<Map<String, dynamic>>? _lastTopStudents;
  List<Map<String, dynamic>>? _lastOverdueRecords;

  Future<int> getCurrentBorrowedCount() async {
    try {
      final records = await _borrowService.getActiveBorrowRecords();
      return records.fold<int>(0, (sum, record) => sum + record.quantity);
    } catch (e) {
      print('获取在借图书数量失败: $e');
      return 0;
    }
  }

  Future<int> getOverdueCount() async {
    try {
      final records = await _borrowService.getOverdueRecords();
      return records.length;
    } catch (e) {
      print('获取逾期图书数量失败: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getTopBorrowedBooks() async {
    try {
      final firstDayOfMonth = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        1,
      );
      final records = (await _borrowService.getAllBorrowRecords())
          .where((record) => record.borrowDate.isAfter(firstDayOfMonth))
          .toList();

      final bookCount = <int, Map<String, dynamic>>{};
      for (final record in records) {
        final existing = bookCount[record.bookId];
        if (existing != null) {
          existing['count'] = (existing['count'] as int) + record.quantity;
        } else {
          bookCount[record.bookId] = {
            'book_id': record.bookId,
            'title': record.bookTitle,
            'author': record.bookAuthor,
            'cover_image_url': record.bookCoverImageUrl,
            'count': record.quantity,
          };
        }
      }

      final sortedBooks = bookCount.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      final topBooks = sortedBooks.take(5).toList();
      _lastTopBooks = topBooks;
      return topBooks;
    } catch (e) {
      print('获取热门图书失败: $e');
      return _lastTopBooks ?? [];
    }
  }

  Future<List<Map<String, dynamic>>> getTopActiveStudents() async {
    try {
      final firstDayOfMonth = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        1,
      );
      final records = (await _borrowService.getAllBorrowRecords())
          .where((record) => record.borrowDate.isAfter(firstDayOfMonth))
          .where((record) => record.studentId != null)
          .toList();

      final studentCount = <int, Map<String, dynamic>>{};
      for (final record in records) {
        final studentId = record.studentId!;
        final existing = studentCount[studentId];
        if (existing != null) {
          existing['count'] = (existing['count'] as int) + record.quantity;
        } else {
          final student = await _studentService.getStudentById(studentId);
          studentCount[studentId] = {
            'student_id': studentId,
            'full_name': student?.fullName ?? record.studentName,
            'class_name': student?.className,
            'count': record.quantity,
          };
        }
      }

      final sortedStudents = studentCount.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      final topStudents = sortedStudents.take(5).toList();
      _lastTopStudents = topStudents;
      return topStudents;
    } catch (e) {
      print('获取活跃学生失败: $e');
      return _lastTopStudents ?? [];
    }
  }

  Future<List<Map<String, dynamic>>> getOverdueRecords() async {
    try {
      final records = await _borrowService.getOverdueRecords();
      final overdueRecords = records
          .map(
            (record) => {
              'id': record.id,
              'borrow_date': record.borrowDate.toIso8601String(),
              'due_date': record.dueDate?.toIso8601String(),
              'book_id': record.bookId,
              'student_id': record.studentId,
              'books': {'title': record.bookTitle, 'author': record.bookAuthor},
              'students': record.studentId == null
                  ? null
                  : {'full_name': record.studentName, 'class_name': null},
              'borrower_profile': record.profileId == null
                  ? null
                  : {
                      'full_name':
                          record.borrowerTeacherName ?? record.teacherName,
                    },
              'borrower_name': record.borrowerName,
              'borrower_type': record.borrowerType,
            },
          )
          .toList();
      _lastOverdueRecords = overdueRecords;
      return overdueRecords;
    } catch (e) {
      print('获取逾期记录失败: $e');
      return _lastOverdueRecords ?? [];
    }
  }

  Future<Map<String, dynamic>> getDashboardSummary() async {
    try {
      final books = await _bookService.getBooksWithCategories();
      final students = await _studentService.getAllStudents();
      final allRecords = await _borrowService.getAllBorrowRecords();
      final firstDayOfMonth = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        1,
      );
      final activeRecords = allRecords
          .where((BorrowRecord record) => record.returnDate == null)
          .toList();
      final now = DateTime.now();

      final summary = {
        'total_books': books.fold<int>(
          0,
          (sum, Book book) => sum + book.totalQuantity,
        ),
        'total_students': students.length,
        'monthly_borrows': allRecords
            .where(
              (BorrowRecord record) =>
                  record.borrowDate.isAfter(firstDayOfMonth),
            )
            .length,
        'current_borrowed': activeRecords.fold<int>(
          0,
          (sum, BorrowRecord record) => sum + record.quantity,
        ),
        'overdue_count': activeRecords
            .where(
              (BorrowRecord record) =>
                  record.dueDate != null && record.dueDate!.isBefore(now),
            )
            .length,
      };
      _lastSummary = summary;
      return summary;
    } catch (e) {
      print('获取统计摘要失败: $e');
      return _lastSummary ??
          {
            'total_books': 0,
            'total_students': 0,
            'monthly_borrows': 0,
            'current_borrowed': 0,
            'overdue_count': 0,
          };
    }
  }
}
