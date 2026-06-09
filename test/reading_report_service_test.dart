import 'package:flutter_test/flutter_test.dart';
import 'package:kindergarten_library/models/book.dart';
import 'package:kindergarten_library/models/borrow_record.dart';
import 'package:kindergarten_library/models/student.dart';
import 'package:kindergarten_library/services/reading_report_service.dart';

void main() {
  test('builds student reading report with trends and recommendations', () {
    final now = DateTime(2026, 6, 9, 10);
    final student = Student(id: 1, fullName: '许子祺', className: '小一班');
    final records = [
      _record(
        id: 1,
        bookId: 1,
        student: student,
        borrowDate: DateTime(2026, 5, 20),
        dueDate: now.add(const Duration(days: 2)),
        category: '生活习惯与安全',
        tags: const ['入园适应', '习惯'],
      ),
      _record(
        id: 2,
        bookId: 2,
        student: student,
        borrowDate: DateTime(2026, 4, 8),
        returnDate: DateTime(2026, 4, 18),
        category: '生活习惯与安全',
        tags: const ['习惯'],
      ),
      _record(
        id: 3,
        bookId: 3,
        student: student,
        borrowDate: DateTime(2025, 12, 8),
        returnDate: DateTime(2025, 12, 18),
        category: '故事绘本',
        tags: const ['想象'],
      ),
    ];
    final books = [
      Book(
        id: 4,
        title: '规则小绘本',
        categoryName: '生活习惯与安全',
        tags: const ['习惯', '规则'],
        rating: 4.8,
        availableQuantity: 2,
      ),
      Book(
        id: 1,
        title: '已读图书',
        categoryName: '生活习惯与安全',
        tags: const ['习惯'],
        rating: 5,
        availableQuantity: 2,
      ),
    ];

    final report = ReadingReportService.buildStudentReport(
      student: student,
      records: records,
      books: books,
      now: now,
    );

    expect(report.totalBorrows, 3);
    expect(report.currentBorrows, 1);
    expect(report.dueSoonBorrows, 1);
    expect(report.favoriteCategory, '生活习惯与安全');
    expect(report.favoriteTag, '习惯');
    expect(report.monthlyTrend.last.label, '6月');
    expect(report.termTrend.last.label, '2026春');
    expect(report.recommendations.single.book.title, '规则小绘本');
    expect(report.toExportText(), contains('许子祺'));
  });

  test('builds class report with student rankings and participation', () {
    final now = DateTime(2026, 6, 9, 10);
    final studentA = Student(id: 1, fullName: '许子祺', className: '小一班');
    final studentB = Student(id: 2, fullName: '任小粟', className: '小一班');
    final records = [
      _record(
        id: 1,
        bookId: 1,
        student: studentA,
        borrowDate: DateTime(2026, 6, 1),
        category: '故事绘本',
        tags: const ['想象'],
      ),
      _record(
        id: 2,
        bookId: 2,
        student: studentA,
        borrowDate: DateTime(2026, 6, 2),
        category: '故事绘本',
        tags: const ['想象'],
      ),
    ];
    final books = [
      Book(
        id: 5,
        title: '想象力绘本',
        categoryName: '故事绘本',
        tags: const ['想象'],
        rating: 4.7,
        availableQuantity: 1,
      ),
    ];

    final report = ReadingReportService.buildClassReport(
      className: '小一班',
      students: [studentA, studentB],
      records: records,
      books: books,
      now: now,
    );

    expect(report.studentCount, 2);
    expect(report.activeReaderCount, 1);
    expect(report.totalBorrows, 2);
    expect(report.favoriteCategory, '故事绘本');
    expect(report.studentRankings.first.student.fullName, '许子祺');
    expect(report.studentRankings.last.student.fullName, '任小粟');
    expect(report.studentRankings.last.totalBorrows, 0);
    expect(report.recommendations.single.book.title, '想象力绘本');
    expect(report.toExportText(), contains('班级：小一班'));
  });
}

BorrowRecord _record({
  required int id,
  required int bookId,
  required Student student,
  required DateTime borrowDate,
  DateTime? dueDate,
  DateTime? returnDate,
  String? category,
  List<String> tags = const [],
}) {
  return BorrowRecord(
    id: id,
    bookId: bookId,
    studentId: student.id,
    studentName: student.fullName,
    studentClassName: student.className,
    borrowDate: borrowDate,
    dueDate: dueDate,
    returnDate: returnDate,
    borrowedByUserId: 'teacher-id',
    bookCategoryName: category,
    bookTags: tags,
  );
}
