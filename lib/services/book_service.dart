import 'dart:io';

import 'package:pocketbase/pocketbase.dart';

import '../models/book.dart';
import 'app_exception.dart';
import 'auth_service.dart';
import 'backend/backend_gateway.dart';
import 'backend/pb_mapper.dart';

/// 图书服务层 - 处理所有与 books collection 相关的数据库操作
class BookService {
  static final BookService _instance = BookService._internal();
  factory BookService() => _instance;
  BookService._internal({BackendGateway? backend})
      : _backend = backend ?? backendGateway;

  BookService.withBackend(BackendGateway backend) : _backend = backend;

  final BackendGateway _backend;

  List<Book> _lastBooksWithCategories = const [];

  Stream<List<Book>> getBooksStream() {
    return _backend.pollingListStream(getBooksWithCategories);
  }

  Future<List<Book>> getBooksWithCategories() async {
    try {
      final records = await _backend.getFullList('books', sort: '-created_at');
      final books = await _booksFromRecords(records);
      _lastBooksWithCategories = books;
      return books;
    } catch (e) {
      print('获取图书和分类信息失败: $e');
      if (_lastBooksWithCategories.isNotEmpty) {
        return _lastBooksWithCategories;
      }
      rethrow;
    }
  }

  Future<void> addBook(Book newBook, {int quantity = 1}) async {
    try {
      await _backend.create(
        'books',
        {
          'id': numericRecordId(await _backend.nextNumericId('books')),
          ..._bookBody(newBook),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'last_updated_by': AuthService().currentUserId,
          'total_quantity': quantity,
          'available_quantity': quantity,
        },
      );
    } catch (e) {
      throwServiceException('添加图书失败', e);
    }
  }

  Future<void> updateBook(Book updatedBook) async {
    try {
      if (updatedBook.id == null) {
        throw const InvalidRequestException('更新失败：图书ID不能为空');
      }

      final recordId = await _backend.requireRecordIdByNumericId(
        'books',
        updatedBook.id!,
      );
      await _backend.update(
        'books',
        recordId,
        {
          ..._bookBody(updatedBook),
          'last_updated_by': AuthService().currentUserId,
        },
      );
    } catch (e) {
      throwServiceException('更新图书失败', e);
    }
  }

  Future<void> deleteBook(int bookId) async {
    try {
      final record = await _backend.findByNumericId('books', bookId);
      if (record == null) return;

      final totalQuantity = asInt(record.get('total_quantity'), fallback: 1);
      final availableQuantity = asInt(
        record.get('available_quantity'),
        fallback: 1,
      );

      if (availableQuantity < totalQuantity) {
        throw DeleteBlockedException(
          '无法删除：该图书有 ${totalQuantity - availableQuantity} 本正在被借阅中',
        );
      }

      await _backend.delete('books', record.id);
    } catch (e) {
      throwServiceException('删除图书失败', e);
    }
  }

  Future<String?> uploadBookCover(File imageFile, {String? oldImageUrl}) async {
    throw const UnsupportedFeatureException(
      '精确迁移模式未创建额外文件 collection；当前仅保留原 Supabase cover_image_url',
    );
  }

  Future<List<Book>> searchBooks(String query) async {
    try {
      final keyword = escapeFilterValue(query);
      final records = await _backend.getFullList(
        'books',
        filter:
            'title ~ "$keyword" || author ~ "$keyword" || location ~ "$keyword"',
        sort: '-created_at',
      );
      return _booksFromRecords(records);
    } catch (e) {
      throwServiceException('搜索图书失败', e);
    }
  }

  Future<Book?> getBookById(int id) async {
    try {
      final record = await _backend.findByNumericId('books', id);
      if (record == null) return null;
      return (await _booksFromRecords([record])).first;
    } catch (e) {
      return null;
    }
  }

  Future<void> ensureStorageBucketExists() async {
    // Supabase public schema only stores cover_image_url. Existing URLs are migrated as-is.
  }

  Future<List<Book>> _booksFromRecords(List<RecordModel> records) async {
    Map<int, String> categories = const {};
    try {
      categories = await _categoryNamesById();
    } catch (e) {
      print('加载图书分类映射失败: $e');
    }

    return records.map((record) {
      final data = recordToJson(record);
      final categoryId = asNullableInt(data['category_id']);
      if (categoryId != null) {
        data['categories'] = {'name': categories[categoryId]};
      }
      return Book.fromJson(data);
    }).toList();
  }

  Future<Map<int, String>> _categoryNamesById() async {
    final records = await _backend.getFullList(
      'categories',
      fields: 'id,name',
    );
    return {
      for (final record in records)
        if (asNullableInt(recordToJson(record)['id']) != null)
          asNullableInt(recordToJson(record)['id'])!: record.get<String>(
            'name',
          ),
    };
  }

  Map<String, dynamic> _bookBody(Book book) {
    return {
      'title': book.title,
      'author': book.author,
      'location': book.location,
      'cover_image_url': book.coverImageUrl,
      'status': book.status,
      'total_quantity': book.totalQuantity,
      'available_quantity': book.availableQuantity,
      'category_id': book.categoryId,
    };
  }
}
