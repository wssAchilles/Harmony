import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../models/reading_report.dart';
import '../services/reading_report_service.dart';
import '../ui/widgets/reading_report_widgets.dart';

class ClassReadingReportScreen extends StatefulWidget {
  const ClassReadingReportScreen({super.key, this.initialClassName});

  final String? initialClassName;

  @override
  State<ClassReadingReportScreen> createState() =>
      _ClassReadingReportScreenState();
}

class _ClassReadingReportScreenState extends State<ClassReadingReportScreen> {
  final ReadingReportService _reportService = ReadingReportService();
  final GlobalKey _reportBoundaryKey = GlobalKey();

  List<String> _classNames = [];
  String? _selectedClassName;
  Future<ClassReadingReport>? _reportFuture;
  bool _isLoadingClasses = true;
  String? _classLoadError;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() {
      _isLoadingClasses = true;
      _classLoadError = null;
    });
    try {
      final classes = await _reportService.getClassNames();
      if (!mounted) return;
      final selected = widget.initialClassName != null &&
              classes.contains(widget.initialClassName)
          ? widget.initialClassName
          : (classes.isEmpty ? null : classes.first);
      setState(() {
        _classNames = classes;
        _selectedClassName = selected;
        _reportFuture =
            selected == null ? null : _reportService.getClassReport(selected);
        _isLoadingClasses = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingClasses = false;
        _classLoadError = e.toString();
      });
    }
  }

  void _selectClass(String className) {
    if (_selectedClassName == className) return;
    setState(() {
      _selectedClassName = className;
      _reportFuture = _reportService.getClassReport(className);
    });
  }

  Future<void> _reloadReport() async {
    final className = _selectedClassName;
    if (className == null) {
      await _loadClasses();
      return;
    }
    setState(() {
      _reportFuture = _reportService.getClassReport(className);
    });
  }

  Future<void> _exportSnapshot(ClassReadingReport report) async {
    try {
      final boundary = _reportBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        _showSnackBar('报告内容尚未渲染完成');
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) {
        _showSnackBar('截图生成失败');
        return;
      }

      final safeName = report.className.replaceAll(
        RegExp(r'[^\w\u4e00-\u9fa5-]+'),
        '_',
      );
      final file = File(
        '${Directory.systemTemp.path}/class_reading_report_$safeName.png',
      );
      await file.writeAsBytes(bytes, flush: true);
      await Clipboard.setData(ClipboardData(text: file.path));
      _showSnackBar('班级报告截图已生成，路径已复制：${file.path}');
    } catch (e) {
      _showSnackBar('导出失败: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportFuture = _reportFuture;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('班级阅读报告'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新报告',
            onPressed: _reloadReport,
          ),
          if (reportFuture != null)
            FutureBuilder<ClassReadingReport>(
              future: reportFuture,
              builder: (context, snapshot) {
                return IconButton(
                  icon: const Icon(Icons.ios_share),
                  tooltip: '导出报告截图',
                  onPressed: snapshot.hasData
                      ? () => _exportSnapshot(snapshot.data!)
                      : null,
                );
              },
            ),
        ],
      ),
      body: _isLoadingClasses
          ? const Center(child: CircularProgressIndicator())
          : _classLoadError != null
              ? _buildError(_classLoadError)
              : _classNames.isEmpty
                  ? _buildEmptyClasses()
                  : Column(
                      children: [
                        _buildClassSelector(),
                        Expanded(
                          child: FutureBuilder<ClassReadingReport>(
                            future: reportFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snapshot.hasError) {
                                return _buildError(snapshot.error);
                              }
                              final report = snapshot.data;
                              if (report == null) {
                                return _buildError('报告数据为空');
                              }
                              return _buildReport(report);
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildClassSelector() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Colors.grey.shade100,
      child: DropdownButtonFormField<String>(
        value: _selectedClassName,
        decoration: const InputDecoration(
          labelText: '选择班级',
          prefixIcon: Icon(Icons.groups),
          border: OutlineInputBorder(),
        ),
        items: _classNames
            .map(
              (className) => DropdownMenuItem(
                value: className,
                child: Text(className),
              ),
            )
            .toList(),
        onChanged: (className) {
          if (className != null) _selectClass(className);
        },
      ),
    );
  }

  Widget _buildReport(ClassReadingReport report) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: RepaintBoundary(
        key: _reportBoundaryKey,
        child: ColoredBox(
          color: Colors.grey.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(report),
              const SizedBox(height: 16),
              ReportMetricGrid(
                items: [
                  ReportMetricTileData(
                    label: '学生人数',
                    value: '${report.studentCount}',
                    icon: Icons.people,
                    color: Colors.deepPurple,
                  ),
                  ReportMetricTileData(
                    label: '活跃阅读',
                    value: '${report.activeReaderCount}',
                    icon: Icons.auto_stories,
                    color: Colors.blue,
                  ),
                  ReportMetricTileData(
                    label: '累计借阅',
                    value: '${report.totalBorrows}',
                    icon: Icons.menu_book,
                    color: Colors.green,
                  ),
                  ReportMetricTileData(
                    label: '逾期图书',
                    value: '${report.overdueBorrows}',
                    icon: Icons.warning_amber,
                    color: Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ReportSectionCard(
                title: '班级分类兴趣雷达',
                icon: Icons.radar,
                color: Colors.deepPurple,
                child: InterestRadarChart(
                  items: report.categoryItems,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 16),
              ReportSectionCard(
                title: '分类阅读分布',
                icon: Icons.category_outlined,
                color: Colors.indigo,
                child: ReadingMetricBars(
                  items: report.categoryItems,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 16),
              ReportSectionCard(
                title: '标注兴趣方向',
                icon: Icons.sell_outlined,
                color: Colors.teal,
                child: ReadingMetricBars(
                  items: report.tagItems,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 16),
              _buildTrendSection(report),
              const SizedBox(height: 16),
              _buildStudentRankings(report.studentRankings),
              const SizedBox(height: 16),
              _buildAdviceSection(report),
              const SizedBox(height: 16),
              _buildRecommendations(report.recommendations),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ClassReadingReport report) {
    final participation = report.studentCount == 0
        ? '0%'
        : '${(report.activeReaderCount / report.studentCount * 100).round()}%';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.deepPurple,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Icon(Icons.groups, color: Colors.deepPurple, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.className,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '班级阅读兴趣与习惯分析',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeaderChip('参与度', participation),
              _buildHeaderChip('常借分类', report.favoriteCategory),
              _buildHeaderChip('常借标注', report.favoriteTag),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(40),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label：$value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTrendSection(ClassReadingReport report) {
    return ReportSectionCard(
      title: '月度与学期趋势',
      icon: Icons.show_chart,
      color: Colors.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '近 6 个月',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          ReadingTrendChart(items: report.monthlyTrend, color: Colors.blue),
          const SizedBox(height: 8),
          const Text(
            '近 4 个学期',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          ReadingTrendChart(
            items: report.termTrend,
            color: Colors.deepPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentRankings(List<StudentReadingSummary> rankings) {
    return ReportSectionCard(
      title: '学生阅读排行',
      icon: Icons.leaderboard,
      color: Colors.amber.shade800,
      child: rankings.isEmpty
          ? Text(
              '暂无学生数据',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            )
          : Column(
              children: rankings.take(8).toList().asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final item = entry.value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: rank <= 3
                        ? Colors.amber.shade700
                        : Colors.grey.shade300,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: rank <= 3 ? Colors.white : Colors.grey[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    item.student.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '偏好：${item.favoriteCategory}，在借 ${item.currentBorrows} 本',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '${item.totalBorrows}次',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildAdviceSection(ClassReadingReport report) {
    return ReportSectionCard(
      title: '老师评语与班级建议',
      icon: Icons.rate_review_outlined,
      color: Colors.orange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextBlock('老师评语', report.teacherComment),
          const SizedBox(height: 12),
          _buildTextBlock('班级建议', report.readingSuggestion),
        ],
      ),
    );
  }

  Widget _buildTextBlock(String title, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(text, style: TextStyle(color: Colors.grey[700], height: 1.45)),
        ],
      ),
    );
  }

  Widget _buildRecommendations(List<BookRecommendation> recommendations) {
    return ReportSectionCard(
      title: '按班级兴趣推荐图书',
      icon: Icons.auto_awesome,
      color: Colors.pink,
      child: recommendations.isEmpty
          ? Text(
              '暂无可推荐图书',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            )
          : Column(
              children: recommendations.map((item) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.pink.withAlpha(28),
                    child: Icon(Icons.menu_book, color: Colors.pink.shade600),
                  ),
                  title: Text(
                    item.book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    item.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    item.book.rating == null
                        ? '未评分'
                        : '${item.book.rating!.toStringAsFixed(1)}分',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildEmptyClasses() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              '暂无班级数据',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '先维护学生班级后再生成班级阅读报告。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              '报告加载失败',
              style: TextStyle(
                color: Colors.grey[850],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadClasses,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
