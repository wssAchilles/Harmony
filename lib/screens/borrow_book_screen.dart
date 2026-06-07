import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/student.dart';
import '../services/borrow_service.dart';
import '../services/student_service.dart';
import '../ui/widgets/async_action_button.dart';
import '../ui/widgets/section_card.dart';

/// 借书页面
class BorrowBookScreen extends StatefulWidget {
  final Book book;

  const BorrowBookScreen({super.key, required this.book});

  @override
  State<BorrowBookScreen> createState() => _BorrowBookScreenState();
}

class _BorrowBookScreenState extends State<BorrowBookScreen> {
  final BorrowService _borrowService = BorrowService();
  final StudentService _studentService = StudentService();

  List<Student> _students = [];
  Student? _selectedStudent;
  DateTime? _dueDate;
  bool _isLoading = true;
  bool _isBorrowing = false;
  AsyncActionState _borrowActionState = AsyncActionState.idle;

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _dueDate = DateTime.now().add(const Duration(days: 14)); // 默认借期14天
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);

    try {
      final students = await _studentService.getAllStudents();
      if (!mounted) return;
      setState(() {
        _students = students;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('加载学生列表失败: $e');
    }
  }

  Future<void> _borrowBook() async {
    if (_selectedStudent == null) {
      _showSnackBar('请选择借阅学生');
      return;
    }

    if (_dueDate == null) {
      _showSnackBar('请选择归还日期');
      return;
    }

    setState(() {
      _isBorrowing = true;
      _borrowActionState = AsyncActionState.loading;
    });

    try {
      // 计算借阅天数
      final borrowDays = _dueDate!.difference(DateTime.now()).inDays;

      await _borrowService.borrowBookToStudent(
        book: widget.book,
        student: _selectedStudent!,
        borrowDays: borrowDays > 0 ? borrowDays : 1,
      );

      setState(() {
        _borrowActionState = AsyncActionState.success;
      });
      _showSnackBar('借阅成功！');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _borrowActionState = AsyncActionState.error;
        });
        _showSnackBar('借阅失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isBorrowing = false);
      }
    }
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
      appBar: AppBar(
        title: const Text('借阅图书'),
        backgroundColor: Colors.blue.shade600,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 图书信息卡片
                  SectionCard(
                    child: Row(
                      children: [
                        // 图书封面
                        Container(
                          width: 80,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: widget.book.resolvedCoverImageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    widget.book.resolvedCoverImageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.book,
                                        size: 40,
                                        color: Colors.grey,
                                      );
                                    },
                                  ),
                                )
                              : const Icon(
                                  Icons.book,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                        ),
                        const SizedBox(width: 16),

                        // 图书信息
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.book.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (widget.book.author != null) ...[
                                Text(
                                  '作者: ${widget.book.author}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 4),
                              ],
                              if (widget.book.location != null)
                                Text(
                                  '位置: ${widget.book.location}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 选择学生
                  const Text(
                    '选择借阅学生',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Student>(
                    // ignore: deprecated_member_use
                    value: _selectedStudent,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '请选择学生',
                    ),
                    items: _students.map((student) {
                      return DropdownMenuItem(
                        value: student,
                        child: Text(
                          '${student.fullName} - ${student.className ?? "未分班"}',
                        ),
                      );
                    }).toList(),
                    onChanged: (student) {
                      setState(() => _selectedStudent = student);
                    },
                  ),

                  const SizedBox(height: 24),

                  // 选择归还日期
                  const Text(
                    '预期归还日期',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ??
                            DateTime.now().add(const Duration(days: 14)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => _dueDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            _dueDate != null
                                ? '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}'
                                : '选择日期',
                            style: TextStyle(
                              color: _dueDate != null
                                  ? Colors.black
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // 借阅按钮
                  AsyncActionButton(
                    onPressed: _isBorrowing ? null : _borrowBook,
                    label: '确认借阅',
                    successLabel: '借阅成功',
                    errorLabel: '重试借阅',
                    icon: Icons.bookmark_add_outlined,
                    state: _borrowActionState,
                  ),
                ],
              ),
            ),
    );
  }
}
