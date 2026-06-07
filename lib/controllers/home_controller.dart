import 'package:flutter/foundation.dart' hide Category;

import '../models/book.dart';
import '../models/category.dart';
import '../services/book_service.dart';
import '../services/category_service.dart';

class HomeController extends ChangeNotifier {
  HomeController({
    BookService? bookService,
    CategoryService? categoryService,
  })  : _bookService = bookService ?? BookService(),
        _categoryService = categoryService ?? CategoryService();

  final BookService _bookService;
  final CategoryService _categoryService;

  String _searchQuery = '';
  List<Category> _categories = [];
  int? _selectedCategoryId;
  bool _categoriesLoading = true;
  String? _categoryError;

  String get searchQuery => _searchQuery;
  List<Category> get categories => List.unmodifiable(_categories);
  int? get selectedCategoryId => _selectedCategoryId;
  bool get categoriesLoading => _categoriesLoading;
  String? get categoryError => _categoryError;
  Stream<List<Book>> get booksStream => _bookService.getBooksStream();

  Future<void> initialize() async {
    _bookService.ensureStorageBucketExists();
    await loadCategories();
  }

  Future<void> loadCategories() async {
    _categoriesLoading = true;
    _categoryError = null;
    notifyListeners();

    try {
      _categories = await _categoryService.getAllCategories();
    } catch (e) {
      _categoryError = e.toString();
    } finally {
      _categoriesLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String value) {
    if (_searchQuery == value) return;
    _searchQuery = value;
    notifyListeners();
  }

  void clearSearch() {
    setSearchQuery('');
  }

  void selectCategory(int? categoryId) {
    if (_selectedCategoryId == categoryId) return;
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  List<Book> filterBooks(List<Book> books) {
    var filtered = books;

    final categoryId = _selectedCategoryId;
    if (categoryId != null) {
      filtered =
          filtered.where((book) => book.categoryId == categoryId).toList();
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((book) {
        return book.title.toLowerCase().contains(query) ||
            (book.author?.toLowerCase() ?? '').contains(query) ||
            (book.location?.toLowerCase() ?? '').contains(query) ||
            (book.categoryName?.toLowerCase() ?? '').contains(query);
      }).toList();
    }

    return filtered;
  }
}
