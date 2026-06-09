import '../models/book.dart';
import '../models/borrow_record.dart';
import '../models/reading_report.dart';
import '../models/student.dart';
import 'book_service.dart';
import 'borrow_service.dart';
import 'student_service.dart';

class ReadingReportService {
  ReadingReportService({
    BorrowService? borrowService,
    BookService? bookService,
    StudentService? studentService,
  })  : _borrowService = borrowService ?? BorrowService(),
        _bookService = bookService ?? BookService(),
        _studentService = studentService ?? StudentService();

  final BorrowService _borrowService;
  final BookService _bookService;
  final StudentService _studentService;

  Future<StudentReadingReport> getStudentReport(Student student) async {
    final records = await _borrowService.getStudentBorrowHistory(student.id!);
    final books = await _bookService.getBooksWithCategories();
    return buildStudentReport(
      student: student,
      records: records,
      books: books,
      now: DateTime.now(),
    );
  }

  Future<List<String>> getClassNames() {
    return _studentService.getAllClasses();
  }

  Future<ClassReadingReport> getClassReport(String className) async {
    final students = await _studentService.getStudentsByClass(className);
    final records = await _borrowService.getAllBorrowRecords();
    final books = await _bookService.getBooksWithCategories();
    return buildClassReport(
      className: className,
      students: students,
      records: records
          .where((record) => record.studentClassName == className)
          .toList(),
      books: books,
      now: DateTime.now(),
    );
  }

  static StudentReadingReport buildStudentReport({
    required Student student,
    required List<BorrowRecord> records,
    required List<Book> books,
    required DateTime now,
  }) {
    final activeRecords =
        records.where((record) => !record.isReturned).toList();
    final overdueRecords =
        activeRecords.where((record) => record.isOverdueAt(now)).toList();
    final dueSoonRecords =
        activeRecords.where((record) => record.isDueSoonAt(now)).toList();
    final categoryItems = _topItems(
      records
          .map((record) => record.bookCategoryName)
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty),
      limit: 6,
    );
    final tagItems = _topItems(
      records.expand((record) => record.bookTags),
      limit: 6,
    );

    final recommendations = _recommendBooks(
      books: books,
      readBookIds: records.map((record) => record.bookId).toSet(),
      favoriteCategory:
          categoryItems.isEmpty ? null : categoryItems.first.label,
      favoriteTags: tagItems.map((item) => item.label).toSet(),
      limit: 5,
    );

    return StudentReadingReport(
      student: student,
      totalBorrows: records.length,
      currentBorrows: activeRecords.fold<int>(
        0,
        (sum, record) => sum + record.quantity,
      ),
      returnedBorrows: records.where((record) => record.isReturned).length,
      overdueBorrows: overdueRecords.length,
      dueSoonBorrows: dueSoonRecords.length,
      categoryItems: categoryItems,
      tagItems: tagItems,
      monthlyTrend: _monthlyTrend(records, now: now),
      termTrend: _termTrend(records, now: now),
      recommendations: recommendations,
      readingLevel: _studentReadingLevel(records.length),
      teacherComment: _studentComment(
        totalBorrows: records.length,
        favoriteCategory:
            categoryItems.isEmpty ? null : categoryItems.first.label,
        overdueCount: overdueRecords.length,
      ),
      readingSuggestion: _studentSuggestion(
        totalBorrows: records.length,
        favoriteCategory:
            categoryItems.isEmpty ? null : categoryItems.first.label,
        favoriteTag: tagItems.isEmpty ? null : tagItems.first.label,
        overdueCount: overdueRecords.length,
      ),
    );
  }

  static ClassReadingReport buildClassReport({
    required String className,
    required List<Student> students,
    required List<BorrowRecord> records,
    required List<Book> books,
    required DateTime now,
  }) {
    final activeRecords =
        records.where((record) => !record.isReturned).toList();
    final overdueRecords =
        activeRecords.where((record) => record.isOverdueAt(now)).toList();
    final categoryItems = _topItems(
      records
          .map((record) => record.bookCategoryName)
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty),
      limit: 6,
    );
    final tagItems = _topItems(
      records.expand((record) => record.bookTags),
      limit: 6,
    );
    final activeStudentIds =
        records.map((record) => record.studentId).whereType<int>().toSet();
    final studentRankings = _studentRankings(
      students: students,
      records: records,
      now: now,
    );
    final recommendations = _recommendBooks(
      books: books,
      readBookIds: records.map((record) => record.bookId).toSet(),
      favoriteCategory:
          categoryItems.isEmpty ? null : categoryItems.first.label,
      favoriteTags: tagItems.map((item) => item.label).toSet(),
      limit: 5,
    );

    return ClassReadingReport(
      className: className,
      studentCount: students.length,
      activeReaderCount: activeStudentIds.length,
      totalBorrows: records.length,
      currentBorrows: activeRecords.fold<int>(
        0,
        (sum, record) => sum + record.quantity,
      ),
      overdueBorrows: overdueRecords.length,
      categoryItems: categoryItems,
      tagItems: tagItems,
      monthlyTrend: _monthlyTrend(records, now: now),
      termTrend: _termTrend(records, now: now),
      studentRankings: studentRankings,
      recommendations: recommendations,
      teacherComment: _classComment(
        studentCount: students.length,
        activeReaderCount: activeStudentIds.length,
        favoriteCategory:
            categoryItems.isEmpty ? null : categoryItems.first.label,
      ),
      readingSuggestion: _classSuggestion(
        studentCount: students.length,
        activeReaderCount: activeStudentIds.length,
        overdueCount: overdueRecords.length,
        favoriteCategory:
            categoryItems.isEmpty ? null : categoryItems.first.label,
      ),
    );
  }

  static List<ReadingMetricItem> _topItems(
    Iterable<String> values, {
    required int limit,
  }) {
    final counts = <String, int>{};
    for (final rawValue in values) {
      final value = rawValue.trim();
      if (value.isEmpty) continue;
      counts[value] = (counts[value] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        return countCompare != 0 ? countCompare : a.key.compareTo(b.key);
      });
    return entries
        .take(limit)
        .map((entry) => ReadingMetricItem(label: entry.key, count: entry.value))
        .toList();
  }

  static List<ReadingTrendItem> _monthlyTrend(
    List<BorrowRecord> records, {
    required DateTime now,
  }) {
    final months = List.generate(
      6,
      (index) => DateTime(now.year, now.month - (5 - index), 1),
    );
    final counts = {for (final month in months) _monthKey(month): 0};
    for (final record in records) {
      final key = _monthKey(record.borrowDate);
      if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
    }
    return months
        .map(
          (month) => ReadingTrendItem(
            label: '${month.month}月',
            count: counts[_monthKey(month)] ?? 0,
          ),
        )
        .toList();
  }

  static List<ReadingTrendItem> _termTrend(
    List<BorrowRecord> records, {
    required DateTime now,
  }) {
    final terms = _recentTerms(now, 4);
    final counts = {for (final term in terms) term: 0};
    for (final record in records) {
      final term = _termLabel(record.borrowDate);
      if (counts.containsKey(term)) counts[term] = counts[term]! + 1;
    }
    return terms
        .map((term) => ReadingTrendItem(label: term, count: counts[term] ?? 0))
        .toList();
  }

  static List<String> _recentTerms(DateTime now, int count) {
    final current = _termLabel(now);
    final terms = <String>[current];
    var cursor = _previousTerm(current);
    while (terms.length < count) {
      terms.insert(0, cursor);
      cursor = _previousTerm(cursor);
    }
    return terms;
  }

  static String _previousTerm(String term) {
    final year = int.parse(term.substring(0, 4));
    if (term.endsWith('春')) return '${year - 1}秋';
    return '$year春';
  }

  static String _termLabel(DateTime date) {
    if (date.month >= 2 && date.month <= 7) return '${date.year}春';
    if (date.month >= 8) return '${date.year}秋';
    return '${date.year - 1}秋';
  }

  static String _monthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  static List<StudentReadingSummary> _studentRankings({
    required List<Student> students,
    required List<BorrowRecord> records,
    required DateTime now,
  }) {
    final recordsByStudentId = <int, List<BorrowRecord>>{};
    final recordsByStudentName = <String, List<BorrowRecord>>{};
    for (final record in records) {
      final studentId = record.studentId;
      if (studentId != null) {
        recordsByStudentId.putIfAbsent(studentId, () => []).add(record);
      }
      final studentName = record.studentName;
      if (studentName != null && studentName.isNotEmpty) {
        recordsByStudentName.putIfAbsent(studentName, () => []).add(record);
      }
    }

    final summaries = students.map((student) {
      final studentRecords = student.id == null
          ? recordsByStudentName[student.fullName] ?? const <BorrowRecord>[]
          : recordsByStudentId[student.id!] ??
              recordsByStudentName[student.fullName] ??
              const <BorrowRecord>[];
      final categoryItems = _topItems(
        studentRecords
            .map((record) => record.bookCategoryName)
            .whereType<String>(),
        limit: 1,
      );
      final activeRecords =
          studentRecords.where((record) => !record.isReturned).toList();
      return StudentReadingSummary(
        student: student,
        totalBorrows: studentRecords.length,
        currentBorrows: activeRecords.length,
        overdueBorrows:
            activeRecords.where((record) => record.isOverdueAt(now)).length,
        favoriteCategory:
            categoryItems.isEmpty ? '暂无记录' : categoryItems.first.label,
      );
    }).toList();

    summaries.sort((a, b) {
      final countCompare = b.totalBorrows.compareTo(a.totalBorrows);
      return countCompare != 0
          ? countCompare
          : a.student.fullName.compareTo(b.student.fullName);
    });
    return summaries;
  }

  static List<BookRecommendation> _recommendBooks({
    required List<Book> books,
    required Set<int> readBookIds,
    required String? favoriteCategory,
    required Set<String> favoriteTags,
    required int limit,
  }) {
    final candidates = books.where((book) {
      final id = book.id;
      if (id != null && readBookIds.contains(id)) return false;
      return book.availableQuantity > 0;
    }).map((book) {
      var score = book.rating ?? 0;
      if (favoriteCategory != null && book.categoryName == favoriteCategory) {
        score += 4;
      }
      final matchedTags =
          book.tags.where((tag) => favoriteTags.contains(tag)).length;
      score += matchedTags * 2;
      return _RecommendationScore(book, score, matchedTags);
    }).toList()
      ..sort((a, b) {
        final scoreCompare = b.score.compareTo(a.score);
        if (scoreCompare != 0) return scoreCompare;
        return a.book.title.compareTo(b.book.title);
      });

    return candidates.take(limit).map((candidate) {
      final book = candidate.book;
      final reasonParts = <String>[];
      if (favoriteCategory != null && book.categoryName == favoriteCategory) {
        reasonParts.add('延伸常读分类「$favoriteCategory」');
      }
      if (candidate.matchedTags > 0) {
        reasonParts.add('匹配 ${candidate.matchedTags} 个兴趣标注');
      }
      if ((book.rating ?? 0) >= 4.6) {
        reasonParts.add('馆内评分较高');
      }
      return BookRecommendation(
        book: book,
        reason: reasonParts.isEmpty ? '适合作为新的阅读尝试' : reasonParts.join('，'),
      );
    }).toList();
  }

  static String _studentReadingLevel(int totalBorrows) {
    if (totalBorrows >= 12) return '稳定阅读者';
    if (totalBorrows >= 6) return '兴趣发展中';
    if (totalBorrows >= 1) return '阅读起步';
    return '暂无样本';
  }

  static String _studentComment({
    required int totalBorrows,
    required String? favoriteCategory,
    required int overdueCount,
  }) {
    if (totalBorrows == 0) {
      return '当前还没有借阅样本，可先安排老师带读和短周期借阅。';
    }
    final focus = favoriteCategory == null ? '多个方向' : '「$favoriteCategory」';
    final overdueText = overdueCount > 0 ? '需要继续关注按时归还习惯。' : '归还节奏保持良好。';
    return '孩子近期阅读集中在$focus，累计借阅 $totalBorrows 次，$overdueText';
  }

  static String _studentSuggestion({
    required int totalBorrows,
    required String? favoriteCategory,
    required String? favoriteTag,
    required int overdueCount,
  }) {
    if (totalBorrows == 0) {
      return '建议从短篇绘本和生活习惯类图书开始，建立固定阅读节奏。';
    }
    final interest = favoriteTag ?? favoriteCategory ?? '当前兴趣方向';
    final overdueAdvice = overdueCount > 0 ? '同时缩短借阅周期，帮助形成归还意识。' : '';
    return '建议围绕「$interest」继续做主题延伸，并搭配一个新的分类拓展阅读面。$overdueAdvice';
  }

  static String _classComment({
    required int studentCount,
    required int activeReaderCount,
    required String? favoriteCategory,
  }) {
    if (studentCount == 0) return '当前班级暂无学生数据。';
    final ratio = activeReaderCount / studentCount;
    final focus =
        favoriteCategory == null ? '暂无明显集中方向' : '集中在「$favoriteCategory」';
    if (ratio >= 0.8) {
      return '班级阅读参与度较高，兴趣方向$focus，适合开展主题共读。';
    }
    if (ratio >= 0.4) {
      return '班级已有一定阅读参与度，兴趣方向$focus，可继续提高覆盖面。';
    }
    return '班级阅读参与度偏低，建议从老师带读和班级轮借开始提升参与。';
  }

  static String _classSuggestion({
    required int studentCount,
    required int activeReaderCount,
    required int overdueCount,
    required String? favoriteCategory,
  }) {
    if (studentCount == 0) return '先维护学生名单，再生成班级阅读计划。';
    final focus = favoriteCategory ?? '高兴趣主题';
    final overdueAdvice = overdueCount > 0 ? '逾期记录需要通过统一提醒和集中还书日处理。' : '';
    return '建议围绕「$focus」组织班级共读，并安排低借阅学生参与老师领读。$overdueAdvice';
  }
}

class _RecommendationScore {
  const _RecommendationScore(this.book, this.score, this.matchedTags);

  final Book book;
  final double score;
  final int matchedTags;
}
