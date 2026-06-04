import '../config/backend_config.dart';

/// 图书数据模型 - 与迁移后的 books collection 对应
class Book {
  final int? id;
  final String title;
  final String? author;
  final String? location;
  final String? coverImageUrl;
  final String status;
  final int totalQuantity; // 总数量
  final int availableQuantity; // 可借数量
  final int? categoryId; // 分类ID
  final String? categoryName; // 分类名称（用于UI显示）
  final String? lastUpdatedBy;
  final DateTime? createdAt;

  Book({
    this.id,
    required this.title,
    this.author,
    this.location,
    this.coverImageUrl,
    this.status = 'available',
    this.totalQuantity = 1,
    this.availableQuantity = 1,
    this.categoryId,
    this.categoryName,
    this.lastUpdatedBy,
    this.createdAt,
  });

  /// 从数据库JSON转换为Book对象
  factory Book.fromJson(Map<String, dynamic> json) {
    // 处理关联查询的分类信息
    String? categoryName;
    if (json['categories'] != null) {
      final category = json['categories'] as Map<String, dynamic>;
      categoryName = category['name'] as String?;
    }

    return Book(
      id: _asInt(json['id']),
      title: json['title'] as String,
      author: json['author'] as String?,
      location: json['location'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      status: json['status'] as String? ?? 'available',
      totalQuantity: _asInt(json['total_quantity']) ?? 1,
      availableQuantity: _asInt(json['available_quantity']) ?? 1,
      categoryId: _asInt(json['category_id']),
      categoryName: categoryName,
      lastUpdatedBy: json['last_updated_by'] as String?,
      createdAt: (json['created_at'] ?? json['created']) != null
          ? DateTime.parse((json['created_at'] ?? json['created']) as String)
          : null,
    );
  }

  /// 转换为JSON格式用于数据库操作
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'title': title,
      'author': author,
      'location': location,
      'status': status,
      'total_quantity': totalQuantity,
      'available_quantity': availableQuantity,
      'category_id': categoryId,
    };

    // 只在更新时包含id
    if (id != null) {
      data['id'] = id;
    }

    if (coverImageUrl != null) {
      data['cover_image_url'] = coverImageUrl;
    }

    if (lastUpdatedBy != null) {
      data['last_updated_by'] = lastUpdatedBy;
    }

    return data;
  }

  /// 复制并修改部分字段
  Book copyWith({
    int? id,
    String? title,
    String? author,
    String? location,
    String? coverImageUrl,
    String? status,
    int? totalQuantity,
    int? availableQuantity,
    int? categoryId,
    String? categoryName,
    String? lastUpdatedBy,
    DateTime? createdAt,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      location: location ?? this.location,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      status: status ?? this.status,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 判断图书是否可借
  bool get isAvailable => availableQuantity > 0;

  String? get resolvedCoverImageUrl {
    final url = coverImageUrl;
    if (url == null || url.isEmpty) return null;
    return BackendConfig.resolveFileUrl(url);
  }

  /// 获取图书状态字符串
  String get statusText {
    if (availableQuantity > 0) {
      return '可借';
    } else {
      return '全部借出';
    }
  }

  /// 获取库存信息字符串
  String get stockInfo => '库存: $availableQuantity / $totalQuantity';
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
