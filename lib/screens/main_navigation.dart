import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'home_screen.dart';
import 'student_list_screen.dart';
import 'profile_screen.dart';
import '../ui/motion/motion.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key, this.pages});

  final List<Widget>? pages;

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _previousIndex = 0;
  late final AnimationController _tabTransitionController;
  late final List<Widget> _pages;

  final List<NavigationDestination> _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: '仪表盘',
    ),
    NavigationDestination(
      icon: Icon(Icons.book_outlined),
      selectedIcon: Icon(Icons.book),
      label: '图书',
    ),
    NavigationDestination(
      icon: Icon(Icons.group_outlined),
      selectedIcon: Icon(Icons.group),
      label: '学生',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: '我的',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pages = widget.pages ??
        const [
          DashboardScreen(),
          HomeScreen(),
          StudentListScreen(),
          ProfileScreen(),
        ];
    _tabTransitionController = AnimationController(
      duration: AppMotion.normal,
      vsync: this,
    )..value = 1;
  }

  @override
  void dispose() {
    _tabTransitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final beginOffset = _currentIndex >= _previousIndex
        ? AppMotion.subtleRight
        : AppMotion.subtleLeft;
    final curvedAnimation = CurvedAnimation(
      parent: _tabTransitionController,
      curve: AppMotion.standardCurve,
    );

    return Scaffold(
      body: FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: beginOffset,
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          if (index == _currentIndex) return;
          setState(() {
            _previousIndex = _currentIndex;
            _currentIndex = index;
          });
          _tabTransitionController.forward(from: 0);
        },
        destinations: _destinations,
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black26,
        indicatorColor: Theme.of(context).primaryColor.withAlpha(26),
        animationDuration: AppMotion.slow,
      ),
    );
  }
}
