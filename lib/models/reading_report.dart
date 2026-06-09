import 'book.dart';
import 'student.dart';

class ReadingMetricItem {
  const ReadingMetricItem({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;
}

class ReadingTrendItem {
  const ReadingTrendItem({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;
}

class BookRecommendation {
  const BookRecommendation({
    required this.book,
    required this.reason,
  });

  final Book book;
  final String reason;
}

class StudentReadingReport {
  const StudentReadingReport({
    required this.student,
    required this.totalBorrows,
    required this.currentBorrows,
    required this.returnedBorrows,
    required this.overdueBorrows,
    required this.dueSoonBorrows,
    required this.categoryItems,
    required this.tagItems,
    required this.monthlyTrend,
    required this.termTrend,
    required this.recommendations,
    required this.readingLevel,
    required this.teacherComment,
    required this.readingSuggestion,
  });

  final Student student;
  final int totalBorrows;
  final int currentBorrows;
  final int returnedBorrows;
  final int overdueBorrows;
  final int dueSoonBorrows;
  final List<ReadingMetricItem> categoryItems;
  final List<ReadingMetricItem> tagItems;
  final List<ReadingTrendItem> monthlyTrend;
  final List<ReadingTrendItem> termTrend;
  final List<BookRecommendation> recommendations;
  final String readingLevel;
  final String teacherComment;
  final String readingSuggestion;

  String get favoriteCategory =>
      categoryItems.isEmpty ? '暂无' : categoryItems.first.label;

  String get favoriteTag => tagItems.isEmpty ? '暂无' : tagItems.first.label;

  String toExportText() {
    return [
      '学生阅读报告',
      '姓名：${student.fullName}',
      '班级：${student.className ?? '未分配'}',
      '阅读水平：$readingLevel',
      '累计借阅：$totalBorrows 次',
      '当前在借：$currentBorrows 本',
      '已归还：$returnedBorrows 次',
      '逾期图书：$overdueBorrows 本',
      '常借分类：$favoriteCategory',
      '常借标注：$favoriteTag',
      '老师评语：$teacherComment',
      '阅读建议：$readingSuggestion',
      '推荐图书：${recommendations.map((item) => item.book.title).join('、')}',
    ].join('\n');
  }
}

class StudentReadingSummary {
  const StudentReadingSummary({
    required this.student,
    required this.totalBorrows,
    required this.currentBorrows,
    required this.overdueBorrows,
    required this.favoriteCategory,
  });

  final Student student;
  final int totalBorrows;
  final int currentBorrows;
  final int overdueBorrows;
  final String favoriteCategory;
}

class ClassReadingReport {
  const ClassReadingReport({
    required this.className,
    required this.studentCount,
    required this.activeReaderCount,
    required this.totalBorrows,
    required this.currentBorrows,
    required this.overdueBorrows,
    required this.categoryItems,
    required this.tagItems,
    required this.monthlyTrend,
    required this.termTrend,
    required this.studentRankings,
    required this.recommendations,
    required this.teacherComment,
    required this.readingSuggestion,
  });

  final String className;
  final int studentCount;
  final int activeReaderCount;
  final int totalBorrows;
  final int currentBorrows;
  final int overdueBorrows;
  final List<ReadingMetricItem> categoryItems;
  final List<ReadingMetricItem> tagItems;
  final List<ReadingTrendItem> monthlyTrend;
  final List<ReadingTrendItem> termTrend;
  final List<StudentReadingSummary> studentRankings;
  final List<BookRecommendation> recommendations;
  final String teacherComment;
  final String readingSuggestion;

  String get favoriteCategory =>
      categoryItems.isEmpty ? '暂无' : categoryItems.first.label;

  String get favoriteTag => tagItems.isEmpty ? '暂无' : tagItems.first.label;

  String toExportText() {
    return [
      '班级阅读报告',
      '班级：$className',
      '学生人数：$studentCount 人',
      '活跃阅读：$activeReaderCount 人',
      '累计借阅：$totalBorrows 次',
      '当前在借：$currentBorrows 本',
      '逾期图书：$overdueBorrows 本',
      '常借分类：$favoriteCategory',
      '常借标注：$favoriteTag',
      '老师评语：$teacherComment',
      '阅读建议：$readingSuggestion',
      '推荐图书：${recommendations.map((item) => item.book.title).join('、')}',
    ].join('\n');
  }
}
