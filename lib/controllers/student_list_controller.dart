import 'package:flutter/foundation.dart';

import '../models/student.dart';
import '../services/student_service.dart';

class StudentListController extends ChangeNotifier {
  StudentListController({StudentService? studentService})
      : _studentService = studentService ?? StudentService();

  final StudentService _studentService;

  List<Student> _allStudents = [];
  List<String> _classes = ['全部'];
  String _searchQuery = '';
  String _selectedClass = '全部';
  bool _isLoading = true;
  String? _errorMessage;

  List<Student> get allStudents => List.unmodifiable(_allStudents);
  List<Student> get filteredStudents =>
      List.unmodifiable(_filterStudents(_allStudents));
  List<String> get classes => List.unmodifiable(_classes);
  String get searchQuery => _searchQuery;
  String get selectedClass => _selectedClass;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadStudents() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final students = await _studentService.getAllStudents();
      final classes = await _studentService.getAllClasses();
      _allStudents = students;
      _classes = ['全部', ...classes];
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteStudent(Student student) async {
    await _studentService.deleteStudent(student.id!);
    await loadStudents();
  }

  void setSearchQuery(String value) {
    if (_searchQuery == value) return;
    _searchQuery = value;
    notifyListeners();
  }

  void clearSearch() {
    setSearchQuery('');
  }

  void selectClass(String className) {
    if (_selectedClass == className) return;
    _selectedClass = className;
    notifyListeners();
  }

  @visibleForTesting
  void replaceStudentsForTesting({
    required List<Student> students,
    required List<String> classes,
  }) {
    _allStudents = students;
    _classes = ['全部', ...classes];
    _isLoading = false;
    notifyListeners();
  }

  Map<String, List<Student>> groupedStudents() {
    final grouped = <String, List<Student>>{};
    for (final student in filteredStudents) {
      final className = student.className ?? '未分配班级';
      grouped.putIfAbsent(className, () => []).add(student);
    }
    return grouped;
  }

  List<Student> _filterStudents(List<Student> students) {
    final query = _searchQuery.trim().toLowerCase();
    return students.where((student) {
      final matchesSearch = query.isEmpty ||
          student.fullName.toLowerCase().contains(query) ||
          (student.className?.toLowerCase() ?? '').contains(query);

      final matchesClass =
          _selectedClass == '全部' || student.className == _selectedClass;

      return matchesSearch && matchesClass;
    }).toList();
  }
}
