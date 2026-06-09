import '../utils/app_logger.dart';

import '../models/book.dart';
import '../models/borrow_record.dart';
import '../models/dashboard_data.dart';
import 'book_service.dart';
import 'borrow_reminder_settings_service.dart';
import 'borrow_service.dart';
import 'student_service.dart';

class DashboardService {
  final _bookService = BookService();
  final _borrowService = BorrowService();
  final _reminderSettingsService = BorrowReminderSettingsService();
  final _studentService = StudentService();
  DashboardSummary? _lastSummary;
  List<TopBorrowedBook>? _lastTopBooks;
  List<TopActiveStudent>? _lastTopStudents;
  List<OverdueBorrowRecordView>? _lastOverdueRecords;
  BorrowInsights? _lastInsights;

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

  Future<int> getDueSoonCount({int? withinDays}) async {
    try {
      final effectiveDays = withinDays ?? await _dueSoonDays();
      final records = await _borrowService.getDueSoonRecords(
        withinDays: effectiveDays,
      );
      return records.length;
    } catch (e) {
      AppLogger.warning('获取即将到期图书数量失败: $e');
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

  Future<List<OverdueBorrowRecordView>> getDueSoonRecords({
    int? withinDays,
  }) async {
    try {
      final effectiveDays = withinDays ?? await _dueSoonDays();
      final records = await _borrowService.getDueSoonRecords(
        withinDays: effectiveDays,
      );
      return records.map(OverdueBorrowRecordView.fromBorrowRecord).toList();
    } catch (e) {
      AppLogger.warning('获取即将到期记录失败: $e');
      return [];
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
      final dueSoonDays = await _dueSoonDays();

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
        dueSoonCount: activeRecords
            .where(
              (BorrowRecord record) =>
                  record.isDueSoonAt(now, withinDays: dueSoonDays),
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

  Future<BorrowInsights> getBorrowInsights() async {
    try {
      final records = await _borrowService.getAllBorrowRecords();
      final insights = BorrowInsights(
        categoryItems: _topMetricItems(
          records,
          (record) => record.bookCategoryName?.trim().isNotEmpty == true
              ? record.bookCategoryName!.trim()
              : '未分类',
        ),
        tagItems: _topTagItems(records),
        monthlyTrend: _monthlyTrend(records),
        classRankings: _topMetricItems(
          records.where((record) => record.studentId != null),
          (record) => record.studentClassName?.trim().isNotEmpty == true
              ? record.studentClassName!.trim()
              : '未分配班级',
        ),
      );
      _lastInsights = insights;
      return insights;
    } catch (e) {
      AppLogger.warning('获取借阅洞察失败: $e');
      return _lastInsights ?? const BorrowInsights.empty();
    }
  }

  Future<int> _dueSoonDays() async {
    final settings = await _reminderSettingsService.getSettings();
    return settings.dueSoonDays;
  }

  List<BorrowMetricItem> _topTagItems(List<BorrowRecord> records) {
    final counts = <String, int>{};
    for (final record in records) {
      for (final tag in record.bookTags) {
        final label = tag.trim();
        if (label.isEmpty) continue;
        counts[label] = (counts[label] ?? 0) + record.quantity;
      }
    }
    return _sortedMetricItems(counts, limit: 6);
  }

  List<BorrowMetricItem> _topMetricItems(
    Iterable<BorrowRecord> records,
    String Function(BorrowRecord record) labelFor,
  ) {
    final counts = <String, int>{};
    for (final record in records) {
      final label = labelFor(record);
      counts[label] = (counts[label] ?? 0) + record.quantity;
    }
    return _sortedMetricItems(counts, limit: 6);
  }

  List<MonthlyBorrowTrend> _monthlyTrend(List<BorrowRecord> records) {
    final now = DateTime.now();
    final months = List.generate(6, (index) {
      return DateTime(now.year, now.month - (5 - index), 1);
    });
    final counts = {
      for (final month in months) _monthKey(month): 0,
    };
    for (final record in records) {
      final key = _monthKey(record.borrowDate);
      if (counts.containsKey(key)) {
        counts[key] = counts[key]! + record.quantity;
      }
    }
    return months
        .map(
          (month) => MonthlyBorrowTrend(
            monthLabel: '${month.month}月',
            count: counts[_monthKey(month)] ?? 0,
          ),
        )
        .toList();
  }

  List<BorrowMetricItem> _sortedMetricItems(
    Map<String, int> counts, {
    required int limit,
  }) {
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        return countCompare != 0 ? countCompare : a.key.compareTo(b.key);
      });
    return entries
        .take(limit)
        .map((entry) => BorrowMetricItem(label: entry.key, count: entry.value))
        .toList();
  }

  String _monthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
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
