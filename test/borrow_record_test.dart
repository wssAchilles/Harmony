import 'package:flutter_test/flutter_test.dart';
import 'package:kindergarten_library/models/borrow_record.dart';

void main() {
  test('treats empty optional date fields as null', () {
    final record = BorrowRecord.fromJson({
      'id': 1,
      'book_id': 6,
      'borrow_date': '2025-09-06 16:19:44.040Z',
      'due_date': '',
      'return_date': '',
      'borrowed_by_user_id': '',
      'quantity': 3,
    });

    expect(record.dueDate, isNull);
    expect(record.returnDate, isNull);
    expect(record.borrowDate.year, 2025);
    expect(record.quantity, 3);
  });

  test('uses teacher profile as borrower when student is absent', () {
    final record = BorrowRecord.fromJson({
      'id': 16,
      'book_id': 9,
      'profile_id': 'f8ec1552-f7c9-49fe-b13f-7cf87f9ee390',
      'teacher_name': '开心逗逗儿',
      'borrow_date': '2025-09-06 16:19:32.218Z',
      'borrowed_by_user_id': 'f8ec1552-f7c9-49fe-b13f-7cf87f9ee390',
    });

    expect(record.borrowerName, '开心逗逗儿');
    expect(record.borrowerType, '老师');
  });

  test('uses student as borrower when student id is present', () {
    final record = BorrowRecord.fromJson({
      'id': 18,
      'book_id': 9,
      'student_id': 1,
      'student_name': '许子祺',
      'student_class_name': '大班A',
      'borrow_date': '2025-09-06 16:19:32.218Z',
      'borrowed_by_user_id': 'ff20d126-e22a-464c-acf5-e1db1e5b6fab',
    });

    expect(record.borrowerName, '许子祺');
    expect(record.borrowerType, '学生');
    expect(record.studentClassName, '大班A');
  });

  test('parses book category and tags for borrowing statistics', () {
    final record = BorrowRecord.fromJson({
      'id': 18,
      'book_id': 9,
      'student_id': 1,
      'student_name': '许子祺',
      'borrow_date': '2025-09-06 16:19:32.218Z',
      'borrowed_by_user_id': 'ff20d126-e22a-464c-acf5-e1db1e5b6fab',
      'books': {
        'title': '月亮故事',
        'category_name': '绘本',
        'tags': ['睡前', '亲子'],
      },
    });

    expect(record.bookCategoryName, '绘本');
    expect(record.bookTags, ['睡前', '亲子']);
  });

  test('calculates deterministic due soon state', () {
    final now = DateTime(2026, 6, 9, 10);
    final record = BorrowRecord.fromJson({
      'id': 18,
      'book_id': 9,
      'student_id': 1,
      'student_name': '许子祺',
      'borrow_date': now.subtract(const Duration(days: 10)).toIso8601String(),
      'due_date': now.add(const Duration(days: 2)).toIso8601String(),
      'borrowed_by_user_id': 'teacher-id',
    });

    expect(record.daysUntilDueAt(now), 2);
    expect(record.isDueSoonAt(now), isTrue);
    expect(record.isOverdueAt(now), isFalse);
  });

  test('parses per-borrow reminder days and uses them for due soon state', () {
    final now = DateTime(2026, 6, 9, 10);
    final record = BorrowRecord.fromJson({
      'id': 18,
      'book_id': 9,
      'student_id': 1,
      'borrow_date': now.toIso8601String(),
      'due_date': now.add(const Duration(days: 5)).toIso8601String(),
      'borrowed_by_user_id': 'teacher-id',
      'reminder_days_before': 7,
    });

    expect(record.reminderDaysBefore, 7);
    expect(record.isDueSoonAt(now, withinDays: 3), isTrue);
    expect(record.toJson()['reminder_days_before'], 7);
  });

  test('treats zero reminder days from old PocketBase rows as unset', () {
    final now = DateTime(2026, 6, 9, 10);
    final record = BorrowRecord.fromJson({
      'id': 18,
      'book_id': 9,
      'student_id': 1,
      'borrow_date': now.toIso8601String(),
      'due_date': now.add(const Duration(days: 2)).toIso8601String(),
      'borrowed_by_user_id': 'teacher-id',
      'reminder_days_before': 0,
    });

    expect(record.reminderDaysBefore, isNull);
    expect(record.isDueSoonAt(now, withinDays: 3), isTrue);
  });

  test('excludes records beyond exact due soon window', () {
    final now = DateTime(2026, 6, 9, 10);
    final inside = BorrowRecord.fromJson({
      'id': 18,
      'book_id': 9,
      'student_id': 1,
      'borrow_date': now.toIso8601String(),
      'due_date': now.add(const Duration(days: 3)).toIso8601String(),
      'borrowed_by_user_id': 'teacher-id',
    });
    final outside = BorrowRecord.fromJson({
      'id': 19,
      'book_id': 9,
      'student_id': 1,
      'borrow_date': now.toIso8601String(),
      'due_date': now.add(const Duration(days: 3, hours: 1)).toIso8601String(),
      'borrowed_by_user_id': 'teacher-id',
    });

    expect(inside.isDueSoonAt(now), isTrue);
    expect(outside.isDueSoonAt(now), isFalse);
  });
}
