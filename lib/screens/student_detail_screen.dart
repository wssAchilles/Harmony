import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/borrow_record.dart';
import '../services/borrow_service.dart';
import 'add_edit_student_screen.dart';
import 'student_reading_report_screen.dart';
import '../utils/page_transitions.dart';
import 'package:intl/intl.dart';

/// 学生详情页面
class StudentDetailScreen extends StatefulWidget {
  final Student student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen>
    with TickerProviderStateMixin {
  final BorrowService _borrowService = BorrowService();
  final ScrollController _studentTrendScrollController = ScrollController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<BorrowRecord> _borrowHistory = [];
  List<BorrowRecord> _currentBorrows = [];
  bool _isLoading = true;
  int _totalBorrows = 0;
  int _currentBorrowedQuantity = 0;
  int _dueSoonBooks = 0;
  int _overdueBooks = 0;
  String? _favoriteCategory;
  String? _favoriteTag;
  List<_StudentMetricItem> _categoryStats = [];
  List<_StudentMetricItem> _tagStats = [];
  List<_StudentMonthlyTrend> _monthlyTrend = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _loadStudentBorrows();
  }

  @override
  void dispose() {
    _studentTrendScrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentBorrows() async {
    setState(() => _isLoading = true);

    try {
      final records = await _borrowService.getStudentBorrowHistory(
        widget.student.id!,
      );
      if (!mounted) return;
      final currentBorrows =
          records.where((r) => r.returnDate == null).toList();
      final now = DateTime.now();

      setState(() {
        _borrowHistory = records;
        _currentBorrows = currentBorrows;
        _totalBorrows = records.length;
        _currentBorrowedQuantity = currentBorrows.fold<int>(
          0,
          (sum, record) => sum + record.quantity,
        );
        _dueSoonBooks =
            currentBorrows.where((record) => record.isDueSoonAt(now)).length;
        _overdueBooks =
            currentBorrows.where((record) => record.isOverdueAt(now)).length;
        _favoriteCategory = _mostCommon(
          records
              .map((record) => record.bookCategoryName)
              .whereType<String>()
              .where((category) => category.trim().isNotEmpty),
        );
        _favoriteTag = _mostCommon(
          records.expand((record) => record.bookTags),
        );
        _categoryStats = _metricItems(
          records
              .map((record) => record.bookCategoryName)
              .whereType<String>()
              .where((category) => category.trim().isNotEmpty),
        );
        _tagStats = _metricItems(records.expand((record) => record.bookTags));
        _monthlyTrend = _buildMonthlyTrend(records);
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('加载借阅记录失败: $e');
    }
  }

  Future<void> _returnBook(int recordId) async {
    try {
      await _borrowService.returnBook(recordId);
      if (!mounted) return;
      _showSnackBar('还书成功！');
      _loadStudentBorrows(); // 重新加载数据
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('还书失败: $e');
    }
  }

  void _showReturnDialog(BorrowRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认还书'),
        content: Text('确认归还《${record.bookTitle}》吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _returnBook(record.id);
            },
            child: const Text('确认还书'),
          ),
        ],
      ),
    );
  }

  Future<void> _editStudent() async {
    final result = await Navigator.push(
      context,
      SlidePageRoute(page: AddEditStudentScreen(student: widget.student)),
    );
    if (!mounted) return;
    if (result == true) {
      // 学生信息已更新，重新加载页面
      Navigator.pop(context, true);
    }
  }

  void _openReadingReport() {
    Navigator.push(
      context,
      SlidePageRoute(
        page: StudentReadingReportScreen(student: widget.student),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.student.fullName),
        backgroundColor: Colors.blue.shade600,
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment_outlined),
            onPressed: _openReadingReport,
            tooltip: '阅读报告',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editStudent,
            tooltip: '编辑学生信息',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                slivers: [
                  // 学生基本信息卡片
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildStudentInfoCard(),
                    ),
                  ),

                  // 统计信息卡片
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildStatisticsCard(),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _buildPreferenceReportCard(),
                    ),
                  ),

                  // 当前借阅
                  if (_currentBorrows.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Text(
                          '当前借阅',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: _buildBorrowRecordCard(
                            _currentBorrows[index],
                            true,
                          ),
                        ),
                        childCount: _currentBorrows.length,
                      ),
                    ),
                  ],

                  // 借阅历史
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                        '借阅历史',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  _borrowHistory.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.history,
                                    size: 64,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '暂无借阅记录',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: _buildBorrowRecordCard(
                                _borrowHistory[index],
                                false,
                              ),
                            ),
                            childCount: _borrowHistory.length,
                          ),
                        ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
    );
  }

  Widget _buildPreferenceReportCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '阅读偏好报告',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: _openReadingReport,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('完整报告'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_borrowHistory.isEmpty)
              Text(
                '暂无借阅样本',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              )
            else ...[
              Text(
                '累计 ${_borrowHistory.length} 次借阅，偏好方向以分类和标注统计。',
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),
              const SizedBox(height: 16),
              _buildMetricBars('分类兴趣', _categoryStats, Colors.indigo),
              const SizedBox(height: 12),
              _buildMetricBars('标注兴趣', _tagStats, Colors.teal),
              const SizedBox(height: 12),
              _buildStudentTrend(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBars(
    String title,
    List<_StudentMetricItem> items,
    Color color,
  ) {
    if (items.isEmpty) {
      return Text(
        '$title：暂无数据',
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      );
    }
    final maxCount = items.fold<int>(
      1,
      (max, item) => item.count > max ? item.count : max,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                  ),
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: item.count / maxCount,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    color: color,
                    backgroundColor: color.withAlpha(28),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${item.count}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStudentTrend() {
    const chartHeight = 132.0;
    const barSlotWidth = 52.0;
    final maxCount = _monthlyTrend.fold<int>(
      1,
      (max, item) => item.count > max ? item.count : max,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '月度趋势',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 158,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = math.max(
                constraints.maxWidth,
                _monthlyTrend.length * barSlotWidth,
              );
              final hasHorizontalOverflow =
                  _monthlyTrend.length * barSlotWidth > constraints.maxWidth;

              return Scrollbar(
                controller: _studentTrendScrollController,
                thumbVisibility: hasHorizontalOverflow,
                trackVisibility: hasHorizontalOverflow,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                child: SingleChildScrollView(
                  controller: _studentTrendScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 18),
                  child: SizedBox(
                    width: contentWidth,
                    height: chartHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: _monthlyTrend.map((item) {
                        final height = 18 + item.count / maxCount * 58;
                        return SizedBox(
                          width: barSlotWidth,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  height: 18,
                                  child: Text(
                                    '${item.count}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 76,
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      width: double.infinity,
                                      height: height,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade500,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 20,
                                  child: Text(
                                    item.monthLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStudentInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.blue.shade500, Colors.blue.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white,
              child: Text(
                widget.student.fullName.isNotEmpty
                    ? widget.student.fullName[0]
                    : '?',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.student.fullName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.student.className != null)
              Text(
                widget.student.className!,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                final columns = constraints.maxWidth >= 560 ? 4 : 2;
                final itemWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _buildStatItem(
                        '总借阅',
                        _totalBorrows.toString(),
                        Icons.book,
                        Colors.blue,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildStatItem(
                        '当前在借',
                        _currentBorrowedQuantity.toString(),
                        Icons.book_outlined,
                        Colors.green,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildStatItem(
                        '即将到期',
                        _dueSoonBooks.toString(),
                        Icons.event_available,
                        Colors.amber,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildStatItem(
                        '逾期图书',
                        _overdueBooks.toString(),
                        Icons.warning,
                        Colors.red,
                      ),
                    ),
                  ],
                );
              },
            ),
            if (_favoriteCategory != null || _favoriteTag != null) ...[
              const Divider(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_favoriteCategory != null)
                    _buildPreferenceChip(
                      '常借分类',
                      _favoriteCategory!,
                      Icons.category,
                      Colors.indigo,
                    ),
                  if (_favoriteTag != null)
                    _buildPreferenceChip(
                      '常借标注',
                      _favoriteTag!,
                      Icons.local_offer,
                      Colors.teal,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return SizedBox(
      height: 112,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceChip(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label：$value',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[800],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBorrowRecordCard(BorrowRecord record, bool isCurrent) {
    final now = DateTime.now();
    final isOverdue = isCurrent && record.isOverdueAt(now);
    final isDueSoon = isCurrent && record.isDueSoonAt(now);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: isOverdue
                  ? Colors.red
                  : isDueSoon
                      ? Colors.amber[700]
                      : (isCurrent ? Colors.orange : Colors.green),
              child: Icon(
                isCurrent ? Icons.book_outlined : Icons.check,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: _buildBorrowRecordContent(record, isCurrent)),
            if (isCurrent) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 88,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => _showReturnDialog(record),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOverdue ? Colors.red : Colors.green,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    '还书',
                    style: TextStyle(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBorrowRecordContent(BorrowRecord record, bool isCurrent) {
    final now = DateTime.now();
    final isOverdue = isCurrent && record.isOverdueAt(now);
    final isDueSoon = isCurrent && record.isDueSoonAt(now);
    final detailStyle = TextStyle(fontSize: 14, color: Colors.grey[600]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                record.bookTitle ?? '未知图书',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '×${record.quantity}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 2,
          children: [
            Text(
              '借阅日期: ${DateFormat('yyyy-MM-dd').format(record.borrowDate)}',
              style: detailStyle,
            ),
            Text(
              '数量: ${record.quantity} 本',
              style: detailStyle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (isCurrent) ...[
          const SizedBox(height: 2),
          Text(
            _borrowStatusText(record, now),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isOverdue
                  ? Colors.red
                  : isDueSoon
                      ? Colors.amber[900]
                      : Colors.grey[600],
              fontWeight:
                  isOverdue || isDueSoon ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ] else if (record.returnDate != null) ...[
          const SizedBox(height: 2),
          Text(
            '归还日期: ${DateFormat('yyyy-MM-dd').format(record.returnDate!)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: detailStyle,
          ),
        ],
      ],
    );
  }

  String _borrowStatusText(BorrowRecord record, DateTime now) {
    final dueDate = record.dueDate;
    if (dueDate == null) return '未设置应还日期';

    if (record.isOverdueAt(now)) {
      final overdueDays = -record.daysUntilDueAt(now);
      return '已逾期 ${overdueDays <= 0 ? 1 : overdueDays} 天';
    }

    final dueDateText = DateFormat('yyyy-MM-dd').format(dueDate);
    final daysLeft = record.daysUntilDueAt(now);
    if (daysLeft <= 0) return '今日到期，应还日期: $dueDateText';
    if (record.isDueSoonAt(now)) {
      return '即将到期，剩余 $daysLeft 天，应还日期: $dueDateText';
    }
    return '应还日期: $dueDateText';
  }

  String? _mostCommon(Iterable<String> values) {
    final counts = <String, int>{};
    for (final rawValue in values) {
      final value = rawValue.trim();
      if (value.isEmpty) continue;
      counts[value] = (counts[value] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;

    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        return countCompare != 0 ? countCompare : a.key.compareTo(b.key);
      });
    return sorted.first.key;
  }

  List<_StudentMetricItem> _metricItems(Iterable<String> values) {
    final counts = <String, int>{};
    for (final rawValue in values) {
      final value = rawValue.trim();
      if (value.isEmpty) continue;
      counts[value] = (counts[value] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        return countCompare != 0 ? countCompare : a.key.compareTo(b.key);
      });
    return sorted
        .take(5)
        .map((entry) => _StudentMetricItem(entry.key, entry.value))
        .toList();
  }

  List<_StudentMonthlyTrend> _buildMonthlyTrend(List<BorrowRecord> records) {
    final now = DateTime.now();
    final months = List.generate(
      6,
      (index) => DateTime(now.year, now.month - (5 - index), 1),
    );
    final counts = {
      for (final month in months) _monthKey(month): 0,
    };
    for (final record in records) {
      final key = _monthKey(record.borrowDate);
      if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
    }
    return months
        .map(
          (month) => _StudentMonthlyTrend(
            '${month.month}月',
            counts[_monthKey(month)] ?? 0,
          ),
        )
        .toList();
  }

  String _monthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }
}

class _StudentMetricItem {
  const _StudentMetricItem(this.label, this.count);

  final String label;
  final int count;
}

class _StudentMonthlyTrend {
  const _StudentMonthlyTrend(this.monthLabel, this.count);

  final String monthLabel;
  final int count;
}
