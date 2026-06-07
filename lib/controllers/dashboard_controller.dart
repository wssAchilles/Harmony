import 'package:flutter/foundation.dart';

import '../models/dashboard_data.dart';
import '../services/dashboard_service.dart';

abstract class DashboardDataSource {
  Future<DashboardSummary> getDashboardSummary();
  Future<List<TopBorrowedBook>> getTopBorrowedBooks();
  Future<List<TopActiveStudent>> getTopActiveStudents();
}

class DashboardServiceDataSource implements DashboardDataSource {
  DashboardServiceDataSource({DashboardService? dashboardService})
      : _dashboardService = dashboardService ?? DashboardService();

  final DashboardService _dashboardService;

  @override
  Future<DashboardSummary> getDashboardSummary() {
    return _dashboardService.getDashboardSummary();
  }

  @override
  Future<List<TopBorrowedBook>> getTopBorrowedBooks() {
    return _dashboardService.getTopBorrowedBooks();
  }

  @override
  Future<List<TopActiveStudent>> getTopActiveStudents() {
    return _dashboardService.getTopActiveStudents();
  }
}

class DashboardController extends ChangeNotifier {
  DashboardController({DashboardDataSource? dataSource})
      : _dataSource = dataSource ?? DashboardServiceDataSource();

  final DashboardDataSource _dataSource;

  DashboardSummary _summary = const DashboardSummary.empty();
  List<TopBorrowedBook> _topBooks = [];
  List<TopActiveStudent> _topStudents = [];
  bool _isLoading = true;
  String? _errorMessage;

  DashboardSummary get summary => _summary;
  List<TopBorrowedBook> get topBooks => List.unmodifiable(_topBooks);
  List<TopActiveStudent> get topStudents => List.unmodifiable(_topStudents);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final summary = await _dataSource.getDashboardSummary();
      final topBooks = await _dataSource.getTopBorrowedBooks();
      final topStudents = await _dataSource.getTopActiveStudents();

      _summary = summary;
      _topBooks = topBooks;
      _topStudents = topStudents;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
