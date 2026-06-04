import '../models/category.dart';
import 'backend/pb_mapper.dart';
import 'backend/pocketbase_client.dart';

class CategoryService {
  Future<void> addCategory(String name) async {
    try {
      await pb
          .collection('categories')
          .create(
            body: {
              'id': numericRecordId(await nextNumericId('categories')),
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
      final records = await pb
          .collection('categories')
          .getFullList(sort: 'created_at');
      return records
          .map((record) => Category.fromJson(recordToJson(record)))
          .toList();
    } catch (e) {
      print('获取分类列表失败: $e');
      return [];
    }
  }

  Stream<List<Category>> getCategoriesStream() {
    return pollingListStream(getAllCategories);
  }

  Future<void> updateCategory(Category category) async {
    try {
      final recordId = await requireRecordIdByNumericId(
        'categories',
        category.id,
      );
      await pb
          .collection('categories')
          .update(recordId, body: {'name': category.name.trim()});
    } catch (e) {
      print('更新分类失败: $e');
      rethrow;
    }
  }

  Future<void> deleteCategory(int categoryId) async {
    try {
      final booksCount = await _getBooksCountByCategory(categoryId);
      if (booksCount > 0) {
        throw Exception('无法删除分类：还有 $booksCount 本图书属于此分类');
      }

      final recordId = await requireRecordIdByNumericId(
        'categories',
        categoryId,
      );
      await pb.collection('categories').delete(recordId);
    } catch (e) {
      print('删除分类失败: $e');
      rethrow;
    }
  }

  Future<void> forceDeleteCategory(int categoryId) async {
    try {
      final recordId = await requireRecordIdByNumericId(
        'categories',
        categoryId,
      );
      await pb.collection('categories').delete(recordId);
    } catch (e) {
      print('强制删除分类失败: $e');
      rethrow;
    }
  }

  Future<int> _getBooksCountByCategory(int categoryId) async {
    try {
      final records = await pb
          .collection('books')
          .getFullList(filter: 'category_id = $categoryId', fields: 'id');
      return records.length;
    } catch (e) {
      print('获取分类图书数量失败: $e');
      return 0;
    }
  }

  Future<Category?> getCategoryById(int categoryId) async {
    try {
      final record = await findByNumericId('categories', categoryId);
      if (record == null) return null;
      return Category.fromJson(recordToJson(record));
    } catch (e) {
      print('获取分类详情失败: $e');
      return null;
    }
  }

  Future<bool> isCategoryNameExists(String name, {int? excludeId}) async {
    try {
      final records = await pb
          .collection('categories')
          .getFullList(
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
