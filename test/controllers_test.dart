import 'package:flutter_test/flutter_test.dart';
import 'package:kindergarten_library/controllers/dashboard_controller.dart';
import 'package:kindergarten_library/controllers/home_controller.dart';
import 'package:kindergarten_library/controllers/student_list_controller.dart';
import 'package:kindergarten_library/models/book.dart';
import 'package:kindergarten_library/models/category.dart';
import 'package:kindergarten_library/models/dashboard_data.dart';
import 'package:kindergarten_library/models/student.dart';
import 'package:kindergarten_library/services/category_service.dart';
import 'package:kindergarten_library/services/student_service.dart';

void main() {
  test('HomeController filters books by category and query', () {
    final controller = HomeController();
    final books = [
      Book(id: 1, title: '小熊绘本', author: '张老师', categoryId: 1),
      Book(id: 2, title: '月亮故事', author: '李老师', categoryId: 2),
    ];

    controller.selectCategory(1);
    expect(controller.filterBooks(books).map((book) => book.id), [1]);

    controller.selectCategory(null);
    controller.setSearchQuery('月亮');
    expect(controller.filterBooks(books).map((book) => book.id), [2]);
  });

  test('HomeController exposes category loading success state', () async {
    final controller = HomeController(
      categoryService: _FakeCategoryService(
        categories: [
          Category(id: 1, name: '绘本', createdAt: DateTime(2026)),
        ],
      ),
    );
    final loadingStates = <bool>[];
    controller.addListener(() {
      loadingStates.add(controller.categoriesLoading);
    });

    await controller.loadCategories();

    expect(controller.categoriesLoading, isFalse);
    expect(controller.categoryError, isNull);
    expect(controller.categories.single.name, '绘本');
    expect(loadingStates, [true, false]);
  });

  test('HomeController exposes category loading failure state', () async {
    final controller = HomeController(
      categoryService: _FakeCategoryService(error: StateError('category boom')),
    );

    await controller.loadCategories();

    expect(controller.categoriesLoading, isFalse);
    expect(controller.categoryError, contains('category boom'));
    expect(controller.categories, isEmpty);
  });

  test('StudentListController filters students by class and query', () {
    final controller = StudentListController()
      ..replaceStudentsForTesting(
        students: [
          Student(id: 1, fullName: '小明', className: '大班A'),
          Student(id: 2, fullName: '小红', className: '中班B'),
        ],
        classes: ['大班A', '中班B'],
      );

    controller.selectClass('大班A');
    expect(controller.filteredStudents.map((student) => student.id), [1]);

    controller.selectClass('全部');
    controller.setSearchQuery('小红');
    expect(controller.filteredStudents.map((student) => student.id), [2]);
  });

  test('StudentListController exposes loading success state', () async {
    final controller = StudentListController(
      studentService: _FakeStudentService(
        students: [Student(id: 1, fullName: '小明', className: '大班A')],
        classes: ['大班A'],
      ),
    );
    final loadingStates = <bool>[];
    controller.addListener(() {
      loadingStates.add(controller.isLoading);
    });

    await controller.loadStudents();

    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, isNull);
    expect(controller.filteredStudents.single.fullName, '小明');
    expect(controller.classes, ['全部', '大班A']);
    expect(loadingStates, [true, false]);
  });

  test('StudentListController exposes loading failure state', () async {
    final controller = StudentListController(
      studentService: _FakeStudentService(error: StateError('student boom')),
    );

    await controller.loadStudents();

    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, contains('student boom'));
    expect(controller.filteredStudents, isEmpty);
  });

  test('DashboardController loads dashboard data', () async {
    final controller = DashboardController(
      dataSource: _FakeDashboardDataSource(),
    );
    final loadingStates = <bool>[];
    controller.addListener(() {
      loadingStates.add(controller.isLoading);
    });

    await controller.load();

    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, isNull);
    expect(controller.summary.totalBooks, 12);
    expect(controller.topBooks.single.title, '小熊绘本');
    expect(controller.topStudents.single.fullName, '小明');
    expect(loadingStates, [true, false]);
  });

  test('DashboardController exposes load failures', () async {
    final controller = DashboardController(
      dataSource: _FakeDashboardDataSource(shouldThrow: true),
    );

    await controller.load();

    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, contains('boom'));
    expect(controller.summary.totalBooks, 0);
  });
}

class _FakeCategoryService implements CategoryService {
  _FakeCategoryService({this.categories = const [], this.error});

  final List<Category> categories;
  final Object? error;

  @override
  Future<List<Category>> getAllCategories() async {
    final error = this.error;
    if (error != null) throw error;
    return categories;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStudentService implements StudentService {
  _FakeStudentService({
    this.students = const [],
    this.classes = const [],
    this.error,
  });

  final List<Student> students;
  final List<String> classes;
  final Object? error;

  @override
  Future<List<Student>> getAllStudents() async {
    final error = this.error;
    if (error != null) throw error;
    return students;
  }

  @override
  Future<List<String>> getAllClasses() async {
    final error = this.error;
    if (error != null) throw error;
    return classes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDashboardDataSource implements DashboardDataSource {
  _FakeDashboardDataSource({this.shouldThrow = false});

  final bool shouldThrow;

  void _maybeThrow() {
    if (shouldThrow) throw StateError('boom');
  }

  @override
  Future<DashboardSummary> getDashboardSummary() async {
    _maybeThrow();
    return const DashboardSummary(
      totalBooks: 12,
      totalStudents: 4,
      monthlyBorrows: 8,
      currentBorrowed: 3,
      overdueCount: 1,
    );
  }

  @override
  Future<List<TopBorrowedBook>> getTopBorrowedBooks() async {
    _maybeThrow();
    return const [
      TopBorrowedBook(bookId: 1, count: 2, title: '小熊绘本'),
    ];
  }

  @override
  Future<List<TopActiveStudent>> getTopActiveStudents() async {
    _maybeThrow();
    return const [
      TopActiveStudent(studentId: 1, count: 2, fullName: '小明'),
    ];
  }
}
