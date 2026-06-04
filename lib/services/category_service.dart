import '../models/category.dart';
import 'app_exception.dart';
import 'backend/backend_gateway.dart';
import 'backend/pb_mapper.dart';

class CategoryService {
  CategoryService({BackendGateway? backend})
      : _backend = backend ?? backendGateway;

  final BackendGateway _backend;

  Future<void> addCategory(String name) async {
    try {
      await _backend.create(
        'categories',
        {
          'id': numericRecordId(await _backend.nextNumericId('categories')),
          'name': name.trim(),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      print('添加分类失败: $e');
      rethrow;
    }
  }

  Future<List<Category>> getAllCategories() async {
    try {
      final records = await _backend.getFullList(
        'categories',
        sort: 'created_at',
      );
      return records
          .map((record) => Category.fromJson(recordToJson(record)))
          .toList();
    } catch (e) {
      print('获取分类列表失败: $e');
      return [];
    }
  }

  Stream<List<Category>> getCategoriesStream() {
    return _backend.pollingListStream(getAllCategories);
  }

  Future<void> updateCategory(Category category) async {
    try {
      final recordId = await _backend.requireRecordIdByNumericId(
        'categories',
        category.id,
      );
      await _backend.update(
        'categories',
        recordId,
        {'name': category.name.trim()},
      );
    } catch (e) {
      print('更新分类失败: $e');
      rethrow;
    }
  }

  Future<void> deleteCategory(int categoryId) async {
    try {
      final booksCount = await _getBooksCountByCategory(categoryId);
      if (booksCount > 0) {
        throw DeleteBlockedException('无法删除分类：还有 $booksCount 本图书属于此分类');
      }

      final recordId = await _backend.requireRecordIdByNumericId(
        'categories',
        categoryId,
      );
      await _backend.delete('categories', recordId);
    } catch (e) {
      print('删除分类失败: $e');
      rethrow;
    }
  }

  Future<void> forceDeleteCategory(int categoryId) async {
    try {
      final recordId = await _backend.requireRecordIdByNumericId(
        'categories',
        categoryId,
      );
      await _backend.delete('categories', recordId);
    } catch (e) {
      print('强制删除分类失败: $e');
      rethrow;
    }
  }

  Future<int> _getBooksCountByCategory(int categoryId) async {
    try {
      final records = await _backend.getFullList(
        'books',
        filter: 'category_id = $categoryId',
        fields: 'id',
      );
      return records.length;
    } catch (e) {
      print('获取分类图书数量失败: $e');
      return 0;
    }
  }

  Future<Category?> getCategoryById(int categoryId) async {
    try {
      final record = await _backend.findByNumericId('categories', categoryId);
      if (record == null) return null;
      return Category.fromJson(recordToJson(record));
    } catch (e) {
      print('获取分类详情失败: $e');
      return null;
    }
  }

  Future<bool> isCategoryNameExists(String name, {int? excludeId}) async {
    try {
      final records = await _backend.getFullList(
        'categories',
        filter: 'name = "${escapeFilterValue(name.trim())}"',
        fields: 'id',
      );
      return records.any((record) => asInt(record.id) != excludeId);
    } catch (e) {
      print('检查分类名称失败: $e');
      return false;
    }
  }
}
