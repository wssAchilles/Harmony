import 'package:flutter_test/flutter_test.dart';
import 'package:kindergarten_library/models/book.dart';
import 'package:kindergarten_library/controllers/book_form_controller.dart';

void main() {
  test('parses extended book fields from json', () {
    final book = Book.fromJson({
      'id': 1,
      'title': '小熊绘本',
      'author': '张老师',
      'publisher': '童心出版社',
      'isbn': '9787111111111',
      'location': 'A架1层',
      'tags': ['绘本', '动物'],
      'rating': 4.5,
    });

    expect(book.publisher, '童心出版社');
    expect(book.isbn, '9787111111111');
    expect(book.tags, ['绘本', '动物']);
    expect(book.rating, 4.5);
  });

  test('builds new book from form fields', () {
    final controller = BookFormController();
    addTearDown(controller.dispose);

    controller.titleController.text = '小熊绘本';
    controller.authorController.text = '张老师';
    controller.publisherController.text = '童心出版社';
    controller.isbnController.text = '9787111111111';
    controller.locationController.text = 'A架1层';
    controller.tagsController.text = '绘本，动物 睡前';
    controller.ratingController.text = '4.5';
    controller.quantityController.text = '3';

    final book = controller.buildBook(
      coverImageUrl: '/covers/book.png',
      selectedCategory: null,
    );

    expect(book.title, '小熊绘本');
    expect(book.author, '张老师');
    expect(book.publisher, '童心出版社');
    expect(book.isbn, '9787111111111');
    expect(book.location, 'A架1层');
    expect(book.tags, ['绘本', '动物', '睡前']);
    expect(book.rating, 4.5);
    expect(book.totalQuantity, 3);
    expect(book.availableQuantity, 3);
    expect(controller.addQuantity, 3);
  });

  test('validates edit inventory consistency', () {
    final controller = BookFormController(
      initialBook: Book(
        id: 1,
        title: '旧书',
        totalQuantity: 5,
        availableQuantity: 2,
      ),
    );
    addTearDown(controller.dispose);

    controller.totalQuantityController.text = '1';
    controller.availableQuantityController.text = '2';

    expect(controller.validateTotalQuantity('1'), '总库存不能小于在馆数量');
  });

  test('validates optional rating range', () {
    final controller = BookFormController();
    addTearDown(controller.dispose);

    expect(controller.validateRating(''), isNull);
    expect(controller.validateRating('5'), isNull);
    expect(controller.validateRating('6'), '评分必须在0到5之间');
    expect(controller.validateRating('abc'), '请输入0到5之间的评分');
  });
}
