import '../utils/app_logger.dart';

import '../models/book.dart';
import '../models/borrow_record.dart';
import '../models/dashboard_data.dart';
import 'book_service.dart';
import 'borrow_service.dart';
import 'student_service.dart';

class DashboardService {
  final _bookService = BookService();
  final _borrowService = BorrowService();
  final _studentService = StudentService();
  DashboardSummary? _lastSummary;
  List<TopBorrowedBook>? _lastTopBooks;
  List<TopActiveStudent>? _lastTopStudents;
  List<OverdueBorrowRecordView>? _lastOverdueRecords;

  Future<int> getCurrentBorrowedCount() async {
    try {
      final records = await _borrowService.getActiveBorrowRecords();
      return records.fold<int>(0, (sum, record) => sum + record.quantity);
    } catch (e) {
      AppLogger.warning('获取在借图书数量失败: $e');
      return 0;
    }
  }

  Future<int> getOverdueCount() async {
    try {
      final records = await _borrowService.getOverdueRecords();
      return records.length;
    } catch (e) {
      AppLogger.warning('获取逾期图书数量失败: $e');
      return 0;
    }
  }

  Future<List<TopBorrowedBook>> getTopBorrowedBooks() async {
    try {
      final firstDayOfMonth = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        1,
      );
      final records = (await _borrowService.getAllBorrowRecords())
          .where((record) => record.borrowDate.isAfter(firstDayOfMonth))
          .toList();

      final bookCount = <int, _BookBorrowCount>{};
      for (final record in records) {
        final existing = bookCount[record.bookId];
        if (existing != null) {
          existing.count += record.quantity;
        } else {
          bookCount[record.bookId] = _BookBorrowCount(
            bookId: record.bookId,
            title: record.bookTitle,
            author: record.bookAuthor,
            coverImageUrl: record.bookCoverImageUrl,
            count: record.quantity,
          );
        }
      }

      final sortedBooks = bookCount.values.toList()
        ..sort((a, b) => b.count.compareTo(a.count));
      final topBooks = sortedBooks
          .take(5)
          .map(
            (book) => TopBorrowedBook(
              bookId: book.bookId,
              title: book.title,
              author: book.author,
              coverImageUrl: book.coverImageUrl,
              count: book.count,
            ),
          )
          .toList();
      _lastTopBooks = topBooks;
      return topBooks;
    } catch (e) {
      AppLogger.warning('获取热门图书失败: $e');
      return _lastTopBooks ?? [];
    }
  }

  Future<List<TopActiveStudent>> getTopActiveStudents() async {
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

      final studentCount = <int, _StudentBorrowCount>{};
      for (final record in records) {
        final studentId = record.studentId!;
        final existing = studentCount[studentId];
        if (existing != null) {
          existing.count += record.quantity;
        } else {
          final student = await _studentService.getStudentById(studentId);
          studentCount[studentId] = _StudentBorrowCount(
            studentId: studentId,
            fullName: student?.fullName ?? record.studentName,
            className: student?.className,
            count: record.quantity,
          );
        }
      }

      final sortedStudents = studentCount.values.toList()
        ..sort((a, b) => b.count.compareTo(a.count));
      final topStudents = sortedStudents
          .take(5)
          .map(
            (student) => TopActiveStudent(
              studentId: student.studentId,
              fullName: student.fullName,
              className: student.className,
              count: student.count,
            ),
          )
          .toList();
      _lastTopStudents = topStudents;
      return topStudents;
    } catch (e) {
      AppLogger.warning('获取活跃学生失败: $e');
      return _lastTopStudents ?? [];
    }
  }

  Future<List<OverdueBorrowRecordView>> getOverdueRecords() async {
    try {
      final records = await _borrowService.getOverdueRecords();
      final overdueRecords =
          records.map(OverdueBorrowRecordView.fromBorrowRecord).toList();
      _lastOverdueRecords = overdueRecords;
      return overdueRecords;
    } catch (e) {
      AppLogger.warning('获取逾期记录失败: $e');
      return _lastOverdueRecords ?? [];
    }
  }

  Future<DashboardSummary> getDashboardSummary() async {
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

      final summary = DashboardSummary(
        totalBooks: books.fold<int>(
          0,
          (sum, Book book) => sum + book.totalQuantity,
        ),
        totalStudents: students.length,
        monthlyBorrows: allRecords
            .where(
              (BorrowRecord record) =>
                  record.borrowDate.isAfter(firstDayOfMonth),
            )
            .length,
        currentBorrowed: activeRecords.fold<int>(
          0,
          (sum, BorrowRecord record) => sum + record.quantity,
        ),
        overdueCount: activeRecords
            .where(
              (BorrowRecord record) =>
                  record.dueDate != null && record.dueDate!.isBefore(now),
            )
            .length,
      );
      _lastSummary = summary;
      return summary;
    } catch (e) {
      AppLogger.warning('获取统计摘要失败: $e');
      return _lastSummary ?? const DashboardSummary.empty();
    }
  }
}

class _BookBorrowCount {
  _BookBorrowCount({
    required this.bookId,
    required this.count,
    this.title,
    this.author,
    this.coverImageUrl,
  });

  final int bookId;
  final String? title;
  final String? author;
  final String? coverImageUrl;
  int count;
}

class _StudentBorrowCount {
  _StudentBorrowCount({
    required this.studentId,
    required this.count,
    this.fullName,
    this.className,
  });

  final int studentId;
  final String? fullName;
  final String? className;
  int count;
}
