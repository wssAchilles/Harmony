import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/student.dart';
import '../controllers/student_list_controller.dart';
import 'add_edit_student_screen.dart';
import 'student_detail_screen.dart';
import '../utils/page_transitions.dart';
import '../ui/motion/motion.dart';
import '../ui/widgets/empty_state_view.dart';
import '../ui/widgets/error_state_view.dart';

/// 学生列表管理页面
class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final TextEditingController _searchController = TextEditingController();

  StudentListController get _controller =>
      context.read<StudentListController>();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 加载学生列表
  Future<void> _loadStudents() async {
    await _controller.loadStudents();
    if (_controller.errorMessage != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text('加载学生列表失败: ${_controller.errorMessage}')),
      );
    }
  }

  /// 删除学生
  Future<void> _deleteStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除学生 "${student.fullName}" 吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _controller.deleteStudent(student);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('学生删除成功')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  /// 导航到添加/编辑学生页面
  void _navigateToAddEdit([Student? student]) {
    Navigator.push(
      context,
      student == null
          ? ScalePageRoute(page: AddEditStudentScreen(student: student))
          : SlidePageRoute(page: AddEditStudentScreen(student: student)),
    ).then((_) => _loadStudents());
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StudentListController>();
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('学生管理'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(120),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 搜索框
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '搜索学生姓名或班级...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _controller.searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _controller.clearSearch();
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (value) {
                        _controller.setSearchQuery(value);
                      },
                    ),
                    const SizedBox(height: 12),

                    // 班级筛选
                    Row(
                      children: [
                        const Icon(Icons.filter_list, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          '班级:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _controller.classes.map((className) {
                                final isSelected =
                                    _controller.selectedClass == className;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(className),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      _controller.selectClass(className);
                                    },
                                    backgroundColor: Colors.grey[200],
                                    selectedColor: Theme.of(
                                      context,
                                    ).primaryColor.withAlpha(51),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadStudents,
                  child: AnimatedSwitcher(
                    duration: AppMotion.normal,
                    child: _buildStudentList(),
                  ),
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _navigateToAddEdit(),
            tooltip: '添加学生',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildStudentList() {
    if (_controller.errorMessage != null && _controller.allStudents.isEmpty) {
      return ErrorStateView(
        title: '学生列表加载失败',
        message: _controller.errorMessage,
        onRetry: _loadStudents,
      );
    }

    if (_controller.filteredStudents.isEmpty) {
      return _buildEmptyState();
    }

    return _buildStudentGroupList(_controller.groupedStudents());
  }

  /// 构建空状态显示
  Widget _buildEmptyState() {
    return EmptyStateView(
      icon: Icons.group_outlined,
      title: _controller.searchQuery.isNotEmpty ? '没有找到匹配的学生' : '暂无学生信息',
      message:
          _controller.searchQuery.isNotEmpty ? '请尝试其他搜索关键词' : '添加学生后即可开始借阅管理',
      action: _controller.searchQuery.isEmpty
          ? ElevatedButton.icon(
              onPressed: () => _navigateToAddEdit(),
              icon: const Icon(Icons.person_add),
              label: const Text('添加第一个学生'),
            )
          : null,
    );
  }

  /// 构建学生分组列表
  Widget _buildStudentGroupList(Map<String, List<Student>> groupedStudents) {
    final sortedClasses = groupedStudents.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: sortedClasses.length,
      itemBuilder: (context, index) {
        final className = sortedClasses[index];
        final classStudents = groupedStudents[className]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 班级标题
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withAlpha(77),
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.class_,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    className,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${classStudents.length} 人',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            // 学生列表
            ...classStudents.map(
              (student) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Text(
                    student.fullName.isNotEmpty ? student.fullName[0] : '?',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(student.fullName),
                subtitle: student.className != null
                    ? Row(
                        children: [
                          Icon(
                            Icons.school,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(student.className!),
                        ],
                      )
                    : null,
                trailing: PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('编辑'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('删除', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _navigateToAddEdit(student);
                    } else if (value == 'delete') {
                      _deleteStudent(student);
                    }
                  },
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    SlidePageRoute(
                      page: StudentDetailScreen(student: student),
                    ),
                  ).then((_) => _loadStudents());
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
