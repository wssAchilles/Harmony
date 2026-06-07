import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../screens/overdue_records_screen.dart';
import '../screens/admin/all_borrow_records_screen.dart';
import 'package:intl/intl.dart';
import '../utils/page_transitions.dart';
import '../ui/motion/motion.dart';
import '../ui/widgets/error_state_view.dart';
import '../ui/widgets/section_card.dart';
import 'package:shimmer/shimmer.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  DashboardController? _controller;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: AppMotion.emphasizedCurve,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<DashboardController>();
    if (identical(_controller, controller)) return;
    _controller?.removeListener(_handleDashboardState);
    _controller = controller;
    controller.addListener(_handleDashboardState);
    _handleDashboardState();
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleDashboardState);
    _animationController.dispose();
    super.dispose();
  }

  void _handleDashboardState() {
    if (!mounted) return;
    final controller = _controller;
    if (controller == null) return;
    if (controller.isLoading) {
      _animationController.reset();
      return;
    }
    if (controller.errorMessage == null && !_animationController.isAnimating) {
      _animationController.forward();
    }
  }

  Future<void> _loadDashboardData() async {
    final controller = _controller;
    if (controller == null) return;
    _animationController.reset();
    await controller.load();
    if (controller.errorMessage == null) {
      _animationController.forward();
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text('加载数据失败: ${controller.errorMessage}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAdminAccess = context.select<AuthController, bool>(
      (auth) => auth.isLoggedIn && auth.isAdmin,
    );
    final controller = context.watch<DashboardController>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final content = controller.isLoading
              ? _buildSkeletonUI()
              : controller.errorMessage != null
                  ? CustomScrollView(
                      slivers: [
                        SliverFillRemaining(
                          child: ErrorStateView(
                            title: '仪表盘加载失败',
                            message: controller.errorMessage,
                            onRetry: _loadDashboardData,
                          ),
                        ),
                      ],
                    )
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: CustomScrollView(
                        slivers: [
                          SliverAppBar(
                            expandedHeight: 120,
                            floating: false,
                            pinned: true,
                            backgroundColor: Colors.blue.shade600,
                            flexibleSpace: FlexibleSpaceBar(
                              title: const Text(
                                '图书馆仪表盘',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              background: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade600,
                                      Colors.blue.shade800,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 2.2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              delegate: SliverChildListDelegate([
                                _buildStaggered(
                                  index: 0,
                                  child: _buildStatCard(
                                    title: '图书总数',
                                    value: '${controller.summary.totalBooks}',
                                    icon: Icons.menu_book,
                                    color: Colors.blue,
                                  ),
                                ),
                                _buildStaggered(
                                  index: 1,
                                  child: _buildStatCard(
                                    title: '学生总数',
                                    value:
                                        '${controller.summary.totalStudents}',
                                    icon: Icons.people,
                                    color: Colors.green,
                                  ),
                                ),
                                _buildStaggered(
                                  index: 2,
                                  child: _buildStatCard(
                                    title: '当前在借',
                                    value:
                                        '${controller.summary.currentBorrowed}',
                                    icon: Icons.book_outlined,
                                    color: Colors.orange,
                                  ),
                                ),
                                _buildStaggered(
                                  index: 3,
                                  child: _buildStatCard(
                                    title: '逾期未还',
                                    value: '${controller.summary.overdueCount}',
                                    icon: Icons.warning,
                                    color: Colors.red,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        SlidePageRoute(
                                          page: const OverdueRecordsScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ]),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverToBoxAdapter(
                              child: _buildStaggered(
                                index: 4,
                                child: _buildMonthlyStatCard(
                                  hasAdminAccess: hasAdminAccess,
                                  monthlyBorrows:
                                      controller.summary.monthlyBorrows,
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SliverToBoxAdapter(
                              child: _buildStaggered(
                                index: 5,
                                child: _buildRankingCard(
                                  title: '🔥 本月热门图书',
                                  items: controller.topBooks,
                                  titleFor: (book) => book.title ?? '',
                                  subtitleFor: (book) => book.author ?? '未知作者',
                                  countFor: (book) => book.count,
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SliverToBoxAdapter(
                              child: _buildStaggered(
                                index: 6,
                                child: _buildRankingCard(
                                  title: '⭐ 本月借阅之星',
                                  items: controller.topStudents,
                                  titleFor: (student) => student.fullName ?? '',
                                  subtitleFor: (student) =>
                                      student.className ?? '未分配班级',
                                  countFor: (student) => student.count,
                                ),
                              ),
                            ),
                          ),
                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 80),
                          ),
                        ],
                      ),
                    );

          return RefreshIndicator(
            onRefresh: _loadDashboardData,
            child: content,
          );
        },
      ),
    );
  }

  Widget _buildStaggered({required int index, required Widget child}) {
    final start = (index * 0.07).clamp(0.0, 0.7);
    final end = (start + 0.35).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(start, end, curve: AppMotion.emphasizedCurve),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: AppMotion.subtleUp,
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return _PressableScale(
      onTap: onTap,
      child: SectionCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 左侧图标区域
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            // 右侧文字区域
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 数值
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                      height: 1.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // 中文标签
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyStatCard({
    required bool hasAdminAccess,
    required int monthlyBorrows,
  }) {
    final monthName = DateFormat('yyyy年MM月').format(DateTime.now());
    return GestureDetector(
      onTap: () {
        // 只有管理员才可以访问所有借阅记录页面
        if (hasAdminAccess) {
          Navigator.push(
            context,
            SlidePageRoute(page: const AllBorrowRecordsScreen()),
          );
        }
        // 普通老师点击无反应
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade400, Colors.purple.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withAlpha(77),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.calendar_month,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    monthName,
                    style: TextStyle(
                      color: Colors.white.withAlpha(230),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$monthlyBorrows 次借阅',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // 管理员显示可点击提示
            if (hasAdminAccess)
              Icon(
                Icons.admin_panel_settings,
                color: Colors.white.withAlpha(204),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingCard<T>({
    required String title,
    required List<T> items,
    required String Function(T item) titleFor,
    required String Function(T item) subtitleFor,
    required int Function(T item) countFor,
  }) {
    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.sentiment_satisfied_alt,
                      size: 48,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '本月暂无数据',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildRankingItem(
                rank: index + 1,
                title: titleFor(item),
                subtitle: subtitleFor(item),
                count: countFor(item),
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildRankingItem({
    required int rank,
    required String title,
    required String subtitle,
    required int count,
  }) {
    final medalColors = [Colors.amber, Colors.grey[400]!, Colors.orange[800]!];
    final showMedal = rank <= 3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // 排名标志
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: showMedal ? medalColors[rank - 1] : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color: showMedal ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 图书或学生信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),

          // 借阅次数
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(26),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count次',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 骨架屏UI组件
  Widget _buildSkeletonUI() {
    return CustomScrollView(
      slivers: [
        // 骨架屏App Bar
        SliverAppBar(
          expandedHeight: 120,
          floating: false,
          pinned: true,
          backgroundColor: Colors.blue.shade600,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text(
              '图书馆仪表盘',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),
        // 骨架屏统计卡片
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSkeletonStatCard(),
              childCount: 4,
            ),
          ),
        ),
        // 骨架屏最近活动标题
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          sliver: SliverToBoxAdapter(child: _buildSkeletonSectionTitle()),
        ),
        // 骨架屏活动列表
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSkeletonActivityItem(),
              childCount: 6,
            ),
          ),
        ),
      ],
    );
  }

  // 骨架屏统计卡片
  Widget _buildSkeletonStatCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 骨架屏图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              // 骨架屏文字区域
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 骨架屏数字
                    Container(
                      width: 60,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 骨架屏标签
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 骨架屏章节标题
  Widget _buildSkeletonSectionTitle() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 120,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  // 骨架屏活动项
  Widget _buildSkeletonActivityItem() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 骨架屏图标
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            const SizedBox(width: 12),
            // 骨架屏内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 200,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 骨架屏计数标签
            Container(
              width: 50,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PressableScale extends StatefulWidget {
  const _PressableScale({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1,
        duration: AppMotion.fast,
        curve: AppMotion.standardCurve,
        child: widget.child,
      ),
    );
  }
}
