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
      'borrow_date': '2025-09-06 16:19:32.218Z',
      'borrowed_by_user_id': 'ff20d126-e22a-464c-acf5-e1db1e5b6fab',
    });

    expect(record.borrowerName, '许子祺');
    expect(record.borrowerType, '学生');
  });
}
