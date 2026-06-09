import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../models/book.dart';
import 'add_edit_book_screen.dart';
import 'book_detail_screen.dart';
import 'student_list_screen.dart';
import '../utils/page_transitions.dart';
import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../ui/motion/motion.dart';
import '../ui/widgets/empty_state_view.dart';
import '../ui/widgets/error_state_view.dart';
import '../ui/widgets/status_chip.dart';
import '../utils/search_matcher.dart';

/// 主页界面 - 图书列表页面
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _categoryScrollController = ScrollController();

  HomeController get _controller => context.read<HomeController>();

  @override
  void dispose() {
    _searchController.dispose();
    _categoryScrollController.dispose();
    super.dispose();
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

  /// 处理登出逻辑
  Future<void> _handleLogout() async {
    try {
      await context.read<AuthController>().signOut();
      // Navigator不需要手动导航，AuthGate会自动处理
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('登出失败: $e')));
      }
    }
  }

  /// 构建侧边栏
  Widget _buildDrawer() {
    final auth = context.watch<AuthController>();
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    auth.displayName.isNotEmpty
                        ? auth.displayName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  auth.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  auth.currentUserEmail ?? '',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('图书管理'),
            selected: true,
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('学生管理'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StudentListScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('退出登录', style: TextStyle(color: Colors.red)),
            onTap: () => _handleLogout(),
          ),
        ],
      ),
    );
  }

  /// 导航到图书详情页
  void _navigateToBookDetail(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BookDetailScreen(book: book)),
    );
  }

  /// 构建图书网格项
  Widget _buildBookGridItem(Book book) {
    final query = context.read<HomeController>().searchQuery;
    final titleMatch = SearchMatcher.matchText(book.title, query);
    final assistedMatchLabel = _assistedMatchLabel(book, query);

    return _PressableBookCard(
      onTap: () => _navigateToBookDetail(book),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 图书封面 - 使用缓存图片组件
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: book.resolvedCoverImageUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: Image.network(
                          book.resolvedCoverImageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return AnimatedOpacity(
                                opacity: 1,
                                duration: const Duration(milliseconds: 150),
                                child: child,
                              );
                            }
                            return Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(color: Colors.grey[300]),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.book,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.book,
                          size: 50,
                          color: Colors.grey[400],
                        ),
                      ),
              ),
            ),
            // 图书信息
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 书名
                    _buildHighlightedText(
                      book.title,
                      query,
                      titleMatch,
                      baseStyle: const TextStyle(
                        fontSize: 14,
                        height: 1.1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // 作者
                    if (book.author != null)
                      _buildHighlightedText(
                        book.author!,
                        query,
                        SearchMatcher.matchText(book.author, query),
                        baseStyle: TextStyle(
                          fontSize: 12,
                          height: 1.1,
                          color: Colors.grey[600],
                        ),
                      ),
                    if (book.publisher != null)
                      _buildHighlightedText(
                        book.publisher!,
                        query,
                        SearchMatcher.matchText(book.publisher, query),
                        baseStyle: TextStyle(
                          fontSize: 11,
                          height: 1.1,
                          color: Colors.grey[600],
                        ),
                      ),
                    if (book.rating != null)
                      Text(
                        '评分 ${book.rating!.toStringAsFixed(1)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.1,
                          color: Colors.amber[800],
                        ),
                      ),
                    if (assistedMatchLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        assistedMatchLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.0,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const Spacer(),
                    // 库存信息和状态
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 库存信息
                        Expanded(
                          child: Text(
                            book.stockInfo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        StatusChip(
                          label: book.statusText,
                          backgroundColor: book.isAvailable
                              ? Colors.green[100]!
                              : Colors.orange[100]!,
                          foregroundColor: book.isAvailable
                              ? Colors.green[800]!
                              : Colors.orange[800]!,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(
    String text,
    String query,
    SearchMatch match, {
    required TextStyle baseStyle,
  }) {
    if (!match.hasRange || query.trim().isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }

    final before = text.substring(0, match.start);
    final highlighted = text.substring(match.start, match.end);
    final after = text.substring(match.end);
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: before),
          TextSpan(
            text: highlighted,
            style: baseStyle.copyWith(
              color: Colors.orange[900],
              backgroundColor: Colors.amber[100],
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _assistedMatchLabel(Book book, String query) {
    if (query.trim().isEmpty) return '';
    for (final field in [
      book.title,
      book.author,
      book.publisher,
      book.isbn,
      book.location,
      book.categoryName,
      ...book.tags,
    ]) {
      final label = SearchMatcher.searchAssistLabel(
        SearchMatcher.matchText(field, query).kind,
      );
      if (label.isNotEmpty) return label;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final controller = context.watch<HomeController>();
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: const Text('图书管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: auth.displayName,
            onPressed: () {
              // 显示用户信息对话框
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('用户信息'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('姓名: ${auth.displayName}'),
                      const SizedBox(height: 8),
                      Text('邮箱: ${auth.currentUserEmail ?? "未知"}'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('关闭'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _handleLogout();
                      },
                      child: const Text(
                        '登出',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Column(
            children: [
              // 搜索栏
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.grey[100],
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索书名、作者、ISBN或标注...',
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
              ),

              // 分类筛选栏
              if (!_controller.categoriesLoading &&
                  _controller.categories.isNotEmpty)
                Container(
                  height: 74,
                  color: Colors.grey[100],
                  child: Column(
                    children: [
                      SizedBox(
                        height: 54,
                        child: ListView(
                          controller: _categoryScrollController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                          children: [
                            // "全部"筛选芯片
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: const Text('全部'),
                                selected:
                                    _controller.selectedCategoryId == null,
                                onSelected: (_) {
                                  _controller.selectCategory(null);
                                },
                                backgroundColor: Colors.grey[200],
                                selectedColor: Colors.blue[100],
                                checkmarkColor: Colors.blue[700],
                              ),
                            ),
                            // 分类筛选芯片
                            ..._controller.categories.map(
                              (category) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(
                                    category.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.visible,
                                  ),
                                  selected: _controller.selectedCategoryId ==
                                      category.id,
                                  onSelected: (_) {
                                    _controller.selectCategory(category.id);
                                  },
                                  backgroundColor: Colors.grey[200],
                                  selectedColor: Colors.blue[100],
                                  checkmarkColor: Colors.blue[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildHorizontalScrollIndicator(
                          controller: _categoryScrollController,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),

              // 图书列表
              Expanded(
                child: StreamBuilder<List<Book>>(
                  stream: _controller.booksStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return ErrorStateView(
                        title: '图书加载失败',
                        message: '${snapshot.error}',
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final books = _controller.filterBooks(snapshot.data!);
                    final resultKey = ValueKey(
                      '${_controller.selectedCategoryId}-${_controller.searchQuery}-${books.length}',
                    );

                    if (books.isEmpty) {
                      return AnimatedSwitcher(
                        duration: AppMotion.normal,
                        child: EmptyStateView(
                          key: resultKey,
                          icon: Icons.library_books,
                          title: _controller.searchQuery.isEmpty
                              ? '暂无图书'
                              : '未找到匹配的图书',
                          message: _controller.searchQuery.isEmpty
                              ? '点击右下角按钮添加第一本图书'
                              : '请尝试其他搜索关键词或分类',
                        ),
                      );
                    }

                    return AnimatedSwitcher(
                      duration: AppMotion.normal,
                      child: GridView.builder(
                        key: resultKey,
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.64,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: books.length,
                        itemBuilder: (context, index) {
                          final book = books[index];
                          return _buildBookGridItem(book);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      // 悬浮按钮 - 添加新书
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            ScalePageRoute(page: const AddEditBookScreen()),
          );
        },
        tooltip: '添加新书',
        heroTag: 'add_book_fab',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PressableBookCard extends StatefulWidget {
  const _PressableBookCard({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_PressableBookCard> createState() => _PressableBookCardState();
}

class _PressableBookCardState extends State<_PressableBookCard> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1,
        duration: AppMotion.fast,
        curve: AppMotion.standardCurve,
        child: widget.child,
      ),
    );
  }
}
