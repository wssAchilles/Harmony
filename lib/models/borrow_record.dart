/// 借阅记录数据模型
class BorrowRecord {
  final int id;
  final int bookId;
  final int? studentId; // 学生ID（如果是学生借阅）
  final String? profileId; // 老师profile ID（如果是老师借阅）
  final DateTime borrowDate; // 借阅日期
  final DateTime? dueDate; // 应还日期
  final DateTime? returnDate; // 实际归还日期
  final String borrowedByUserId; // 经办老师ID
  final DateTime? createdAt;
  final int quantity; // 本次借阅的数量

  // 便利字段 - 用于UI显示
  final String? bookTitle;
  final String? studentName;
  final String? teacherName; // 老师姓名（如果是老师借阅）
  final String? bookAuthor;
  final String? bookCoverImageUrl;
  final String? borrowerTeacherName; // 借阅老师姓名（通过profile_id关联）
  final String? handlerTeacherName; // 经办老师姓名（通过borrowed_by_user_id关联）

  BorrowRecord({
    required this.id,
    required this.bookId,
    this.studentId,
    this.profileId,
    required this.borrowDate,
    this.dueDate,
    this.returnDate,
    required this.borrowedByUserId,
    this.createdAt,
    this.quantity = 1, // 默认数量为1
    this.bookTitle,
    this.studentName,
    this.teacherName,
    this.bookAuthor,
    this.bookCoverImageUrl,
    this.borrowerTeacherName,
    this.handlerTeacherName,
  });

  /// 判断是否已归还
  bool get isReturned => returnDate != null;

  /// 判断是否逾期
  bool get isOverdue {
    if (isReturned || dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  String get borrowerName =>
      studentName ?? borrowerTeacherName ?? teacherName ?? '未知借阅人';

  String get borrowerType {
    if (studentId != null) return '学生';
    if (profileId != null) return '老师';
    return '未知';
  }

  /// 计算剩余天数或逾期天数
  int get daysRemaining {
    if (isReturned || dueDate == null) return 0;
    final now = DateTime.now();
    final difference = dueDate!.difference(now).inDays;
    return difference;
  }

  /// 从JSON创建对象
  factory BorrowRecord.fromJson(Map<String, dynamic> json) {
    final studentName = json['student_name'] as String? ??
        json['students']?['full_name'] as String?;
    final teacherName = json['teacher_name'] as String? ??
        json['profiles']?['full_name'] as String?;

    // 解析新的别名字段
    final borrowerTeacherName = json['borrower_teacher_name'] as String? ??
        json['borrower_profile']?['full_name'] as String?;
    final handlerTeacherName = json['handler_teacher_name'] as String? ??
        json['handler_profile']?['full_name'] as String?;

    return BorrowRecord(
      id: _asInt(json['id']) ?? 0,
      bookId: _asInt(json['book_id']) ?? 0,
      studentId: _asInt(json['student_id']),
      profileId: json['profile_id'] as String?,
      borrowDate: _asDateTime(json['borrow_date']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      dueDate: _asDateTime(json['due_date']),
      returnDate: _asDateTime(json['return_date']),
      borrowedByUserId: json['borrowed_by_user_id'] as String? ?? '',
      createdAt: _asDateTime(json['created_at'] ?? json['created']),
      quantity: _asInt(json['quantity']) ?? 1,
      bookTitle:
          json['book_title'] as String? ?? json['books']?['title'] as String?,
      studentName: studentName,
      teacherName: teacherName,
      bookAuthor:
          json['book_author'] as String? ?? json['books']?['author'] as String?,
      bookCoverImageUrl: json['book_cover_image_url'] as String? ??
          json['books']?['cover_image_url'] as String?,
      borrowerTeacherName: borrowerTeacherName,
      handlerTeacherName: handlerTeacherName,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'book_id': bookId,
      'borrow_date': borrowDate.toIso8601String(),
      'borrowed_by_user_id': borrowedByUserId,
      'quantity': quantity, // 添加数量字段
    };

    if (studentId != null) data['student_id'] = studentId;
    if (profileId != null) data['profile_id'] = profileId;
    if (dueDate != null) data['due_date'] = dueDate!.toIso8601String();
    if (returnDate != null) data['return_date'] = returnDate!.toIso8601String();
    if (createdAt != null) data['created_at'] = createdAt!.toIso8601String();

    return data;
  }

  /// 创建副本
  BorrowRecord copyWith({
    int? id,
    int? bookId,
    int? studentId,
    String? profileId,
    DateTime? borrowDate,
    DateTime? dueDate,
    DateTime? returnDate,
    String? borrowedByUserId,
    DateTime? createdAt,
    int? quantity,
  }) {
    return BorrowRecord(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      studentId: studentId ?? this.studentId,
      profileId: profileId ?? this.profileId,
      borrowDate: borrowDate ?? this.borrowDate,
      dueDate: dueDate ?? this.dueDate,
      returnDate: returnDate ?? this.returnDate,
      borrowedByUserId: borrowedByUserId ?? this.borrowedByUserId,
      createdAt: createdAt ?? this.createdAt,
      quantity: quantity ?? this.quantity,
    );
  }
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}
