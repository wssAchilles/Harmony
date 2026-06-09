import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_exception.dart';
import '../services/borrow_service.dart';
import '../models/borrow_record.dart';
import '../services/auth_service.dart';
import '../controllers/auth_controller.dart';
import '../ui/widgets/empty_state_view.dart';
import '../ui/widgets/section_card.dart';
import '../ui/widgets/status_chip.dart';
import '../utils/app_logger.dart';
import 'category_management_screen.dart';
import 'borrow_reminder_settings_screen.dart';
import 'profile_view_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final BorrowService _borrowService = BorrowService();
  final AuthService _authService = AuthService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String? _userId;
  String? _userEmail;
  String? _userName;
  ProfileBorrowSummary _borrowSummary = const ProfileBorrowSummary.empty();
  bool _isLoading = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _loadUserData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthController>();
      await auth.refreshProfile();
      if (!mounted) return;
      if (auth.currentUserId != null) {
        _userId = auth.currentUserId;
        _userEmail = auth.currentUserEmail;

        setState(() {
          _userName = auth.currentProfile?.fullName ?? auth.displayName;
          _nameController.text = _userName ?? '';
        });

        await _loadBorrowSummary();
      }
    } catch (e) {
      AppLogger.warning('加载用户数据失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadBorrowSummary() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      final records = (await _borrowService.getTeacherBorrowHistory(userId))
          .where((record) => record.returnDate == null)
          .toList();
      if (!mounted) return;
      setState(() {
        _borrowSummary = ProfileBorrowSummary(activeBorrows: records);
      });
    } catch (e) {
      AppLogger.warning('加载借阅记录失败: $e');
      if (!mounted) return;
      setState(() {
        _borrowSummary = const ProfileBorrowSummary.empty();
      });
    }
  }

  Future<void> _updateUserName() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('姓名不能为空');
      return;
    }

    try {
      await context.read<AuthController>().updateProfile(
            fullName: _nameController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _userName = _nameController.text.trim();
      });

      _showSnackBar('姓名更新成功', isError: false);
    } catch (e) {
      _showSnackBar('更新失败: ${messageForError(e)}');
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text.length < 6) {
      _showSnackBar('新密码至少需要6个字符');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar('两次输入的密码不一致');
      return;
    }

    try {
      await _authService.updatePassword(
        oldPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      _showSnackBar('密码修改成功', isError: false);
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('密码修改失败: ${messageForError(e)}');
    }
  }

  Future<void> _returnBook(int recordId) async {
    try {
      await _borrowService.returnBook(recordId);
      await _loadBorrowSummary();
      if (!mounted) return;
      _showSnackBar('还书成功', isError: false);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('还书失败: ${messageForError(e)}');
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认退出'),
          content: const Text('您确定要退出登录吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      if (!mounted) return;
      try {
        await context.read<AuthController>().signOut();
      } catch (e) {
        if (!mounted) return;
        _showSnackBar('退出失败: ${messageForError(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('个人中心'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade600,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: '退出登录',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 用户头像和基本信息卡片
                    _buildProfileCard(),
                    const SizedBox(height: 20),

                    // 账户信息卡片
                    _buildAccountInfoCard(),
                    const SizedBox(height: 20),

                    // 我的借阅卡片
                    _buildMyBorrowsCard(),
                    const SizedBox(height: 20),

                    // 安全设置卡片
                    _buildSecurityCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileCard() {
    final auth = context.watch<AuthController>();
    final displayName = auth.displayName;
    final email = auth.currentUserEmail ?? _userEmail ?? '';
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
              radius: 50,
              backgroundColor: Colors.white,
              child: Text(
                displayName.isNotEmpty
                    ? displayName[0].toUpperCase()
                    : email.isNotEmpty
                        ? email[0].toUpperCase()
                        : 'U',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              email,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withAlpha(230),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountInfoCard() {
    final auth = context.watch<AuthController>();
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              const Text(
                '账户信息',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('姓名'),
            subtitle: Text(auth.displayName),
            trailing: IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () {
                _showEditNameDialog();
              },
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('邮箱'),
            subtitle: Text(auth.currentUserEmail ?? ''),
            trailing: const Icon(Icons.email, size: 20, color: Colors.grey),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('角色'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusChip(
                  label: auth.roleDisplayName,
                  backgroundColor:
                      auth.isAdmin ? Colors.red[50]! : Colors.green[50]!,
                  foregroundColor:
                      auth.isAdmin ? Colors.red[700]! : Colors.green[700]!,
                  icon:
                      auth.isAdmin ? Icons.admin_panel_settings : Icons.school,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyBorrowsCard() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.book, color: Colors.orange.shade600),
              const SizedBox(width: 8),
              const Text(
                '我的借阅',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              StatusChip(
                label: '${_borrowSummary.totalQuantity} 本',
                backgroundColor: Colors.orange.shade100,
                foregroundColor: Colors.orange.shade700,
                icon: Icons.menu_book,
              ),
            ],
          ),
          const Divider(height: 24),
          if (_borrowSummary.activeBorrows.isEmpty)
            const EmptyStateView(
              icon: Icons.book_outlined,
              title: '您当前没有借阅的图书',
            )
          else
            ...List.generate(
              _borrowSummary.activeBorrows.length > 3
                  ? 3
                  : _borrowSummary.activeBorrows.length,
              (index) => _buildBorrowItem(
                _borrowSummary.activeBorrows[index],
              ),
            ),
          if (_borrowSummary.activeBorrows.length > 3)
            Center(
              child: TextButton(
                onPressed: () {
                  _showAllBorrowsDialog();
                },
                child: Text(
                  '查看全部 ${_borrowSummary.activeBorrows.length} 本',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBorrowItem(BorrowRecord record) {
    // 使用模型中的业务逻辑，避免空指针异常
    final isOverdue = record.isOverdue;
    final isDueSoon = record.isDueSoonAt(DateTime.now());
    final daysLeft = record.daysRemaining;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOverdue
              ? Colors.red.shade200
              : isDueSoon
                  ? Colors.amber.shade300
                  : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // 图书封面
          Container(
            width: 50,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: record.bookCoverImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      record.bookCoverImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.book, color: Colors.grey);
                      },
                    ),
                  )
                : const Icon(Icons.book, color: Colors.grey),
          ),
          const SizedBox(width: 12),

          // 图书信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.bookTitle ?? '未知书名',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '作者: ${record.bookAuthor ?? '未知'}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '借阅数量: ${record.quantity} 本',
                  style: TextStyle(
                    color: Colors.blue[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isOverdue ? Icons.warning : Icons.schedule,
                      size: 14,
                      color: isOverdue
                          ? Colors.red
                          : isDueSoon
                              ? Colors.amber[800]
                              : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOverdue
                          ? '已逾期 ${-daysLeft} 天'
                          : isDueSoon
                              ? daysLeft > 0
                                  ? '即将到期，剩余 $daysLeft 天'
                                  : '今日到期'
                              : daysLeft > 0
                                  ? '剩余 $daysLeft 天'
                                  : '今日到期',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOverdue
                            ? Colors.red
                            : isDueSoon
                                ? Colors.amber[900]
                                : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 还书按钮
          ElevatedButton(
            onPressed: () => _confirmReturn(record.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: isOverdue ? Colors.red : Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('还书', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _confirmReturn(int recordId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认还书'),
          content: const Text('您确定要归还这本书吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _returnBook(recordId);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSecurityCard() {
    final auth = context.watch<AuthController>();
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: Colors.green.shade600),
              const SizedBox(width: 8),
              const Text(
                '安全设置',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.category),
            title: const Text('分类管理'),
            subtitle: const Text('管理图书分类，添加、编辑或删除分类'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoryManagementScreen(),
                ),
              );
            },
          ),
          if (auth.isAdmin) ...[
            const Divider(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available),
              title: const Text('借阅提醒设置'),
              subtitle: const Text('配置即将到期阈值和默认提醒时间'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BorrowReminderSettingsScreen(),
                  ),
                );
              },
            ),
          ],
          const Divider(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock),
            title: const Text('修改密码'),
            subtitle: const Text('定期更改密码以保护账户安全'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showChangePasswordDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog() {
    _nameController.text = context.read<AuthController>().displayName;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('修改姓名'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '姓名',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateUserName();
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('修改密码'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '新密码',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '确认新密码',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: _changePassword,
              child: const Text('确认修改'),
            ),
          ],
        );
      },
    );
  }

  void _showAllBorrowsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '我的全部借阅',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _borrowSummary.activeBorrows.length,
                    itemBuilder: (context, index) {
                      return _buildBorrowItem(
                        _borrowSummary.activeBorrows[index],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
