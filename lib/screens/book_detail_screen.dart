import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/student.dart';
import '../models/borrow_record.dart';
import '../services/app_exception.dart';
import '../services/book_service.dart';
import '../services/student_service.dart';
import '../services/borrow_service.dart';
import 'add_edit_book_screen.dart';
import 'borrow_quantity_dialog.dart';
import '../ui/widgets/section_card.dart';
import '../ui/widgets/status_chip.dart';
import '../utils/app_logger.dart';

/// 图书详情页面
class BookDetailScreen extends StatefulWidget {
  final Book book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final _bookService = BookService();
  final _studentService = StudentService();
  final _borrowService = BorrowService();

  late Book _currentBook;
  BorrowRecord? _currentBorrowRecord;
  List<BorrowRecord> _currentBorrowRecords = [];
  bool _isLoading = true;

  int get _activeBorrowedQuantity {
    return _currentBorrowRecords.fold<int>(
      0,
      (sum, record) => sum + record.quantity,
    );
  }

  @override
  void initState() {
    super.initState();
    _currentBook = widget.book;
    _loadBookDetails();
  }

  /// 加载图书详细信息和借阅记录
  Future<void> _loadBookDetails() async {
    setState(() => _isLoading = true);

    try {
      // 获取最新的图书信息
      final latestBook = await _bookService.getBookById(_currentBook.id!);
      if (latestBook != null) {
        _currentBook = latestBook;
      }

      _currentBorrowRecords =
          await _borrowService.getActiveBorrowRecordsForBook(
        _currentBook.id!,
      );
      _currentBorrowRecord =
          _currentBorrowRecords.isEmpty ? null : _currentBorrowRecords.first;

      final correctedAvailable =
          _currentBook.totalQuantity - _activeBorrowedQuantity;
      if (correctedAvailable != _currentBook.availableQuantity) {
        _currentBook = _currentBook.copyWith(
          availableQuantity: correctedAvailable.clamp(
            0,
            _currentBook.totalQuantity,
          ),
        );
      }
    } catch (e) {
      AppLogger.warning('加载图书详情失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 显示选择学生对话框
  Future<void> _showStudentSelectionDialog() async {
    final students = await _studentService.getAllStudents();

    if (!mounted) return;

    final selectedStudent = await showDialog<Student>(
      context: context,
      builder: (BuildContext context) {
        String searchQuery = '';

        return StatefulBuilder(
          builder: (context, setState) {
            // 过滤学生列表
            final filteredStudents = students.where((student) {
              if (searchQuery.isEmpty) return true;
              return student.fullName.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      ) ||
                  (student.className?.toLowerCase() ?? '').contains(
                    searchQuery.toLowerCase(),
                  );
            }).toList();

            return AlertDialog(
              title: const Text('选择借阅学生'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    // 搜索框
                    TextField(
                      decoration: const InputDecoration(
                        hintText: '搜索学生姓名或班级...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // 学生列表
                    Expanded(
                      child: filteredStudents.isEmpty
                          ? const Center(child: Text('没有找到匹配的学生'))
                          : ListView.builder(
                              itemCount: filteredStudents.length,
                              itemBuilder: (context, index) {
                                final student = filteredStudents[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text(student.fullName[0]),
                                  ),
                                  title: Text(student.fullName),
                                  subtitle: Text(student.className ?? '未分配班级'),
                                  onTap: () {
                                    Navigator.pop(context, student);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedStudent != null) {
      _borrowToStudent(selectedStudent);
    }
  }

  /// 借书给学生
  Future<void> _borrowToStudent(Student student) async {
    final result = await showDialog<BorrowQuantityResult>(
      context: context,
      builder: (context) => BorrowQuantityDialog(
        title: '确认借阅',
        description: '将《${_currentBook.title}》借给${student.fullName}',
        details: [
          '班级：${student.className ?? '未分配班级'}',
          '借阅期限：14天',
        ],
        availableQuantity: _currentBook.availableQuantity,
        confirmLabel: '确认借出',
      ),
    );

    if (result == null) return;

    setState(() => _isLoading = true);

    try {
      await _borrowService.borrowBookToStudent(
        book: _currentBook,
        student: student,
        quantity: result.quantity,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功借出给${student.fullName}'),
            backgroundColor: Colors.green,
          ),
        );

        // 刷新页面数据
        _loadBookDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('借阅失败: ${messageForError(e)}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  /// 老师自己借阅
  Future<void> _borrowToTeacher() async {
    final result = await showDialog<BorrowQuantityResult>(
      context: context,
      builder: (context) => BorrowQuantityDialog(
        title: '确认借阅',
        description: '确定要借阅《${_currentBook.title}》吗？',
        details: const ['借阅期限：30天'],
        availableQuantity: _currentBook.availableQuantity,
        confirmLabel: '确认借阅',
      ),
    );

    if (result == null) return;

    setState(() => _isLoading = true);

    try {
      await _borrowService.borrowBookToTeacher(
        book: _currentBook,
        quantity: result.quantity,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('借阅成功'), backgroundColor: Colors.green),
        );

        // 刷新页面数据
        _loadBookDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('借阅失败: ${messageForError(e)}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  /// 归还图书
  Future<void> _returnBook() async {
    if (_currentBorrowRecord == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认归还'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确定要归还《${_currentBook.title}》吗？'),
            const SizedBox(height: 8),
            Text(
              '借阅人：${_currentBorrowRecord?.studentName ?? _currentBorrowRecord?.teacherName ?? '未知借阅人'}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              '借出日期：${_formatDate(_currentBorrowRecord!.borrowDate)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (_currentBorrowRecord!.isOverdue)
              Text(
                '已逾期 ${-_currentBorrowRecord!.daysRemaining} 天',
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认归还'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await _borrowService.returnBook(_currentBorrowRecord!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('归还成功'), backgroundColor: Colors.green),
        );

        // 刷新页面数据
        _loadBookDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('归还失败: ${messageForError(e)}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  /// 导航到编辑页面
  void _navigateToEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditBookScreen(book: _currentBook),
      ),
    ).then((_) {
      // 编辑后刷新数据
      _loadBookDetails();
    });
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // 顶部图片和基本信息
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _currentBook.resolvedCoverImageUrl != null
                        ? Image.network(
                            _currentBook.resolvedCoverImageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.book,
                                size: 100,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.book,
                              size: 100,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: _navigateToEdit,
                      tooltip: '编辑图书信息',
                    ),
                  ],
                ),

                // 图书信息和操作按钮
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 书名
                        Text(
                          _currentBook.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        // 作者
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              size: 20,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _currentBook.author ?? '未知作者',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // 分类
                        Row(
                          children: [
                            const Icon(
                              Icons.category_outlined,
                              size: 20,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _currentBook.categoryName?.isNotEmpty == true
                                  ? _currentBook.categoryName!
                                  : '暂时未分类',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // 位置
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 20,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _currentBook.location ?? '未设置位置',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 库存状态卡片
                        SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 库存信息标题
                              Row(
                                children: [
                                  Icon(
                                    Icons.inventory_2,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '库存信息',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 库存详情
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStockItem(
                                    '总数量',
                                    _currentBook.totalQuantity.toString(),
                                    Icons.library_books,
                                    Colors.blue,
                                  ),
                                  _buildStockItem(
                                    '可借数量',
                                    _currentBook.availableQuantity.toString(),
                                    Icons.check_circle,
                                    _currentBook.isAvailable
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                  _buildStockItem(
                                    '已借出',
                                    _activeBorrowedQuantity.toString(),
                                    Icons.person_outline,
                                    Colors.orange,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // 状态标签
                              StatusChip(
                                label: _currentBook.statusText,
                                backgroundColor: _currentBook.isAvailable
                                    ? Colors.green[100]!
                                    : Colors.orange[100]!,
                                foregroundColor: _currentBook.isAvailable
                                    ? Colors.green[700]!
                                    : Colors.orange[700]!,
                                icon: _currentBook.isAvailable
                                    ? Icons.check_circle
                                    : Icons.schedule,
                              ),

                              // 如果有借出记录，显示最近的借阅信息
                              if (_currentBorrowRecords.isNotEmpty) ...[
                                const Divider(height: 24),
                                _buildBorrowInfo(),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 操作按钮
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// 构建借阅信息
  Widget _buildBorrowInfo() {
    if (_currentBorrowRecords.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行：已借出图标和文字
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.schedule,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '已借出',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          for (var index = 0;
              index < _currentBorrowRecords.length;
              index++) ...[
            if (index > 0) const Divider(height: 20),
            _buildSingleBorrowInfo(_currentBorrowRecords[index]),
          ],
        ],
      ),
    );
  }

  Widget _buildSingleBorrowInfo(BorrowRecord record) {
    return Column(
      children: [
        _buildBorrowInfoRow('借阅人', record.borrowerName),
        _buildBorrowInfoRow('借阅类型', record.borrowerType),
        _buildBorrowInfoRow('借阅数量', '${record.quantity} 本'),
        _buildBorrowInfoRow('借出日期', _formatDate(record.borrowDate)),
        _buildBorrowInfoRow(
          '应还日期',
          record.dueDate != null ? _formatDate(record.dueDate!) : '未设置',
        ),
        if (record.isOverdue)
          _buildBorrowInfoRow(
            '逾期天数',
            '${-record.daysRemaining} 天',
            valueColor: Colors.red,
          )
        else if (record.daysRemaining <= 3)
          _buildBorrowInfoRow(
            '剩余天数',
            '${record.daysRemaining} 天',
            valueColor: Colors.orange,
          )
        else
          _buildBorrowInfoRow('剩余天数', '${record.daysRemaining} 天'),
      ],
    );
  }

  /// 构建借阅信息行（卡片内部使用）
  Widget _buildBorrowInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建库存信息项
  Widget _buildStockItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  /// 构建操作按钮
  Widget _buildActionButtons() {
    // 根据可借数量判断是否可以借阅
    if (_currentBook.isAvailable) {
      // 有库存可借：显示借出按钮
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: _showStudentSelectionDialog,
            icon: const Icon(Icons.person_add),
            label: Text('借出此书（给学生）\n还有 ${_currentBook.availableQuantity} 本可借'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _borrowToTeacher,
            icon: const Icon(Icons.book),
            label: const Text('我来借阅'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      );
    } else {
      // 库存不足：显示不可借状态和归还按钮
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 库存不足提示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, size: 20, color: Colors.red[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '库存不足，所有图书均已借出',
                    style: TextStyle(fontSize: 14, color: Colors.red[700]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 如果有借阅记录，显示归还按钮
          if (_currentBorrowRecord != null)
            ElevatedButton.icon(
              onPressed: _returnBook,
              icon: const Icon(Icons.assignment_return),
              label: const Text('办理还书'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      );
    }
  }
}
