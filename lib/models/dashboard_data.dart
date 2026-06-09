import 'borrow_record.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.totalBooks,
    required this.totalStudents,
    required this.monthlyBorrows,
    required this.currentBorrowed,
    required this.overdueCount,
    required this.dueSoonCount,
  });

  const DashboardSummary.empty()
      : totalBooks = 0,
        totalStudents = 0,
        monthlyBorrows = 0,
        currentBorrowed = 0,
        overdueCount = 0,
        dueSoonCount = 0;

  final int totalBooks;
  final int totalStudents;
  final int monthlyBorrows;
  final int currentBorrowed;
  final int overdueCount;
  final int dueSoonCount;
}

class TopBorrowedBook {
  const TopBorrowedBook({
    required this.bookId,
    required this.count,
    this.title,
    this.author,
    this.coverImageUrl,
  });

  final int bookId;
  final int count;
  final String? title;
  final String? author;
  final String? coverImageUrl;
}

class TopActiveStudent {
  const TopActiveStudent({
    required this.studentId,
    required this.count,
    this.fullName,
    this.className,
  });

  final int studentId;
  final int count;
  final String? fullName;
  final String? className;
}

class OverdueBorrowRecordView {
  const OverdueBorrowRecordView({
    required this.id,
    required this.borrowDate,
    required this.bookId,
    required this.borrowerName,
    required this.borrowerType,
    this.dueDate,
    this.studentId,
    this.bookTitle,
    this.bookAuthor,
    this.studentName,
    this.borrowerTeacherName,
  });

  final int id;
  final DateTime borrowDate;
  final DateTime? dueDate;
  final int bookId;
  final int? studentId;
  final String? bookTitle;
  final String? bookAuthor;
  final String? studentName;
  final String? borrowerTeacherName;
  final String borrowerName;
  final String borrowerType;

  factory OverdueBorrowRecordView.fromBorrowRecord(BorrowRecord record) {
    return OverdueBorrowRecordView(
      id: record.id,
      borrowDate: record.borrowDate,
      dueDate: record.dueDate,
      bookId: record.bookId,
      studentId: record.studentId,
      bookTitle: record.bookTitle,
      bookAuthor: record.bookAuthor,
      studentName: record.studentName,
      borrowerTeacherName: record.borrowerTeacherName ?? record.teacherName,
      borrowerName: record.borrowerName,
      borrowerType: record.borrowerType,
    );
  }
}
