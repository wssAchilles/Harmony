import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/category.dart';

class BookFormController {
  BookFormController({this.initialBook}) {
    final book = initialBook;
    if (book != null) {
      titleController.text = book.title;
      authorController.text = book.author ?? '';
      publisherController.text = book.publisher ?? '';
      isbnController.text = book.isbn ?? '';
      locationController.text = book.location ?? '';
      tagsController.text = book.tags.join('，');
      ratingController.text = book.rating?.toString() ?? '';
      totalQuantityController.text = book.totalQuantity.toString();
      availableQuantityController.text = book.availableQuantity.toString();
    }
  }

  final Book? initialBook;
  final titleController = TextEditingController();
  final authorController = TextEditingController();
  final publisherController = TextEditingController();
  final isbnController = TextEditingController();
  final locationController = TextEditingController();
  final tagsController = TextEditingController();
  final ratingController = TextEditingController();
  final quantityController = TextEditingController(text: '1');
  final totalQuantityController = TextEditingController();
  final availableQuantityController = TextEditingController();

  bool get isEditMode => initialBook != null;

  int get addQuantity => int.tryParse(quantityController.text) ?? 1;

  Book buildBook({
    required String? coverImageUrl,
    required Category? selectedCategory,
  }) {
    final book = initialBook;
    final quantity = addQuantity;
    return Book(
      id: book?.id,
      title: titleController.text.trim(),
      author: authorController.text.trim(),
      publisher: _optionalText(publisherController.text),
      isbn: _optionalText(isbnController.text),
      location: locationController.text.trim(),
      coverImageUrl: coverImageUrl,
      categoryId: selectedCategory?.id,
      categoryName: selectedCategory?.name,
      tags: _parseTags(tagsController.text),
      rating: _parseRating(ratingController.text),
      totalQuantity: book != null
          ? int.tryParse(totalQuantityController.text) ?? book.totalQuantity
          : quantity,
      availableQuantity: book != null
          ? int.tryParse(availableQuantityController.text) ??
              book.availableQuantity
          : quantity,
    );
  }

  String? validateRequired(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label不能为空';
    }
    return null;
  }

  String? validateRating(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final rating = double.tryParse(value.trim());
    if (rating == null) return '请输入0到5之间的评分';
    if (rating < 0 || rating > 5) return '评分必须在0到5之间';
    return null;
  }

  String? validateAddQuantity(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '数量不能为空';
    }
    final quantity = int.tryParse(value.trim());
    if (quantity == null || quantity < 1) {
      return '请输入有效的数量（至少1本）';
    }
    if (quantity > 999) {
      return '数量不能超过999';
    }
    return null;
  }

  String? validateTotalQuantity(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '总库存不能为空';
    }
    final totalQuantity = int.tryParse(value.trim());
    if (totalQuantity == null || totalQuantity < 1) {
      return '请输入有效的总数量（至少1本）';
    }
    if (totalQuantity > 9999) {
      return '总数量不能超过9999';
    }
    final availableQuantity =
        int.tryParse(availableQuantityController.text.trim()) ?? 0;
    if (totalQuantity < availableQuantity) {
      return '总库存不能小于在馆数量';
    }
    return null;
  }

  String? validateAvailableQuantity(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '在馆数量不能为空';
    }
    final availableQuantity = int.tryParse(value.trim());
    if (availableQuantity == null || availableQuantity < 0) {
      return '请输入有效的在馆数量（不能为负数）';
    }
    final totalQuantity =
        int.tryParse(totalQuantityController.text.trim()) ?? 0;
    if (availableQuantity > totalQuantity) {
      return '在馆数量不能大于总库存';
    }
    return null;
  }

  void dispose() {
    titleController.dispose();
    authorController.dispose();
    publisherController.dispose();
    isbnController.dispose();
    locationController.dispose();
    tagsController.dispose();
    ratingController.dispose();
    quantityController.dispose();
    totalQuantityController.dispose();
    availableQuantityController.dispose();
  }

  String? _optionalText(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  List<String> _parseTags(String value) {
    return value
        .split(RegExp(r'[,，\s]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  double? _parseRating(String value) {
    if (validateRating(value) != null) return null;
    return double.tryParse(value.trim());
  }
}
