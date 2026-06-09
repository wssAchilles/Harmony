import 'package:flutter/material.dart';
import '../../models/borrow_record.dart';
import '../../services/borrow_service.dart';

/// 超级管理员专属：查看所有借阅记录页面
/// 仅管理员角色可以访问，显示系统中所有用户的借阅历史
class AllBorrowRecordsScreen extends StatefulWidget {
  const AllBorrowRecordsScreen({super.key});

  @override
  State<AllBorrowRecordsScreen> createState() => _AllBorrowRecordsScreenState();
}

class _AllBorrowRecordsScreenState extends State<AllBorrowRecordsScreen> {
  final BorrowService _borrowService = BorrowService();

  List<Map<String, dynamic>> _allRecords = [];
  List<Map<String, dynamic>> _filteredRecords = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = '全部'; // 全部、已归还、未归还、即将到期、逾期

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _filterScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAllBorrowRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filterScrollController.dispose();
    super.dispose();
  }

  /// 加载所有借阅记录（深度关联查询）
  Future<void> _loadAllBorrowRecords() async {
    setState(() => _isLoading = true);

    try {
      final records = await _borrowService.getAllBorrowRecords();

      setState(() {
        _allRecords = records.map(_recordToMap).toList();
        _filteredRecords = _allRecords;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载借阅记录失败: $e')));
      }
    }
  }

  Map<String, dynamic> _recordToMap(BorrowRecord record) {
    return {
      'id': record.id,
      'borrow_date': record.borrowDate.toIso8601String(),
      'due_date': record.dueDate?.toIso8601String(),
      'return_date': record.returnDate?.toIso8601String(),
      'quantity': record.quantity,
      'reminder_days_before': record.reminderDaysBefore,
      'books': {'title': record.bookTitle, 'author': record.bookAuthor},
      'students': record.studentId == null
          ? null
          : {
              'full_name': record.studentName,
              'class_name': record.studentClassName,
            },
      'borrower_profile': record.profileId == null
          ? null
          : {'full_name': record.borrowerTeacherName ?? record.teacherName},
      'handler_profile': {'full_name': record.handlerTeacherName},
      'borrower_type': record.borrowerType,
    };
  }

  /// 应用搜索和筛选
  void _applyFilters() {
    List<Map<String, dynamic>> filtered = _allRecords;

    // 应用状态筛选
    if (_selectedFilter != '全部') {
      filtered = filtered.where((record) {
        switch (_selectedFilter) {
          case '已归还':
            return record['return_date'] != null;
          case '未归还':
            return record['return_date'] == null &&
                (record['due_date'] == null ||
                    DateTime.parse(record['due_date']).isAfter(DateTime.now()));
          case '即将到期':
            return _isDueSoon(record);
          case '逾期':
            return record['return_date'] == null &&
                record['due_date'] != null &&
                DateTime.parse(record['due_date']).isBefore(DateTime.now());
          default:
            return true;
        }
      }).toList();
    }

    // 应用搜索筛选
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((record) {
        final bookTitle =
            record['books']['title']?.toString().toLowerCase() ?? '';
        final bookAuthor =
            record['books']['author']?.toString().toLowerCase() ?? '';
        final studentName =
            record['students']?['full_name']?.toString().toLowerCase() ?? '';
        final borrowerTeacher = record['borrower_profile']?['full_name']
                ?.toString()
                .toLowerCase() ??
            '';
        final handlerTeacher =
            record['handler_profile']?['full_name']?.toString().toLowerCase() ??
                '';
        final borrowerType =
            record['borrower_type']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        return bookTitle.contains(query) ||
            bookAuthor.contains(query) ||
            studentName.contains(query) ||
            borrowerTeacher.contains(query) ||
            handlerTeacher.contains(query) ||
            borrowerType.contains(query);
      }).toList();
    }

    setState(() {
      _filteredRecords = filtered;
    });
  }

  /// 格式化日期显示
  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return '-';
    }
  }

  /// 获取记录状态显示
  Widget _getStatusChip(Map<String, dynamic> record) {
    if (record['return_date'] != null) {
      return Chip(
        label: const Text('已归还'),
        backgroundColor: Colors.green.shade100,
        labelStyle: TextStyle(color: Colors.green.shade800),
      );
    } else if (record['due_date'] != null &&
        DateTime.parse(record['due_date']).isBefore(DateTime.now())) {
      return Chip(
        label: const Text('逾期'),
        backgroundColor: Colors.red.shade100,
        labelStyle: TextStyle(color: Colors.red.shade800),
      );
    } else if (_isDueSoon(record)) {
      final dueDate = DateTime.parse(record['due_date']);
      final daysLeft = dueDate.difference(DateTime.now()).inDays;
      return Chip(
        label: Text(daysLeft <= 0 ? '今日到期' : '即将到期'),
        backgroundColor: Colors.amber.shade100,
        labelStyle: TextStyle(color: Colors.amber.shade900),
      );
    } else {
      return Chip(
        label: const Text('借阅中'),
        backgroundColor: Colors.blue.shade100,
        labelStyle: TextStyle(color: Colors.blue.shade800),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('所有借阅记录'),
            Text(
              '共 ${_filteredRecords.length} 条记录',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllBorrowRecords,
            tooltip: '刷新数据',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 搜索和筛选栏
                _buildFilterSection(),

                // 记录列表
                Expanded(
                  child: _filteredRecords.isEmpty
                      ? const Center(
                          child: Text(
                            '暂无符合条件的借阅记录',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredRecords.length,
                          itemBuilder: (context, index) {
                            final record = _filteredRecords[index];
                            return _buildRecordCard(record);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  /// 构建筛选区域
  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          // 搜索框
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索图书名称、学生/老师姓名或类型',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _applyFilters();
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _applyFilters();
            },
          ),
          const SizedBox(height: 12),

          // 状态筛选
          Column(
            children: [
              SizedBox(
                height: 48,
                child: SingleChildScrollView(
                  controller: _filterScrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['全部', '已归还', '未归还', '即将到期', '逾期'].map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            filter,
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _selectedFilter = filter);
                            _applyFilters();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _buildHorizontalScrollIndicator(
                controller: _filterScrollController,
                color: Colors.deepPurple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalScrollIndicator({
    required ScrollController controller,
    required Color color,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        if (!controller.hasClients) {
          return const SizedBox(height: 6);
        }

        final position = controller.position;
        if (!position.hasContentDimensions || position.maxScrollExtent <= 0) {
          return const SizedBox(height: 6);
        }

        final viewportWidth = position.viewportDimension;
        final contentWidth = viewportWidth + position.maxScrollExtent;
        final thumbFraction = (viewportWidth / contentWidth).clamp(0.12, 1.0);
        final scrollFraction =
            (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0);

        return LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            var thumbWidth = trackWidth * thumbFraction;
            if (thumbWidth < 32) thumbWidth = 32;
            if (thumbWidth > trackWidth) thumbWidth = trackWidth;
            final left = (trackWidth - thumbWidth) * scrollFraction;

            return SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color.withAlpha(32),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Positioned(
                    left: left,
                    top: 0,
                    bottom: 0,
                    width: thumbWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color.withAlpha(180),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 构建借阅记录卡片
  Widget _buildRecordCard(Map<String, dynamic> record) {
    final book = record['books'] as Map<String, dynamic>;
    final student = record['students'] as Map<String, dynamic>?;
    final borrowerProfile = record['borrower_profile'] as Map<String, dynamic>?;
    final handlerProfile = record['handler_profile'] as Map<String, dynamic>?;

    // 确定借阅人：如果有学生信息显示学生，否则显示老师
    final borrowerName =
        student?['full_name'] ?? borrowerProfile?['full_name'] ?? '未知借阅人';
    final borrowerType = student != null ? '学生' : '老师';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：图书和状态
            Row(
              children: [
                Expanded(
                  child: Text(
                    book['title'] ?? '未知图书',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _getStatusChip(record),
              ],
            ),
            const SizedBox(height: 8),

            // 图书作者
            if (book['author'] != null)
              Text(
                '作者：${book['author']}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            const SizedBox(height: 8),

            // 借阅信息
            _buildInfoRow('借阅人', '$borrowerName ($borrowerType)'),
            if (student != null)
              _buildInfoRow('学生班级', student['class_name'] ?? '-'),
            _buildInfoRow('借阅数量', '${record['quantity'] ?? 1} 本'),
            _buildInfoRow('借阅日期', _formatDate(record['borrow_date'])),

            if (record['due_date'] != null)
              _buildInfoRow('应还日期', _formatDate(record['due_date'])),

            _buildInfoRow(
              '提醒时间',
              record['reminder_days_before'] == null ||
                      record['reminder_days_before'] == 0
                  ? '使用默认设置'
                  : '提前 ${record['reminder_days_before']} 天',
            ),

            if (record['return_date'] != null)
              _buildInfoRow('实还日期', _formatDate(record['return_date'])),

            _buildInfoRow('经办老师', handlerProfile?['full_name'] ?? '未知老师'),

            if (record['notes'] != null &&
                record['notes'].toString().isNotEmpty)
              _buildInfoRow('备注', record['notes']),
          ],
        ),
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label：',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  bool _isDueSoon(Map<String, dynamic> record) {
    if (record['return_date'] != null || record['due_date'] == null) {
      return false;
    }
    final dueDate = DateTime.parse(record['due_date']);
    final now = DateTime.now();
    final rawReminderDays = record['reminder_days_before'] as int?;
    final reminderDays =
        rawReminderDays == null || rawReminderDays <= 0 ? 3 : rawReminderDays;
    if (dueDate.isBefore(now)) return false;
    return !dueDate.isAfter(now.add(Duration(days: reminderDays)));
  }
}
