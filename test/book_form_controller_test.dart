import 'package:flutter_test/flutter_test.dart';
import 'package:kindergarten_library/models/book.dart';
import 'package:kindergarten_library/controllers/book_form_controller.dart';

void main() {
  test('builds new book from form fields', () {
    final controller = BookFormController();
    addTearDown(controller.dispose);

    controller.titleController.text = '小熊绘本';
    controller.authorController.text = '张老师';
    controller.locationController.text = 'A架1层';
    controller.quantityController.text = '3';

    final book = controller.buildBook(
      coverImageUrl: '/covers/book.png',
      selectedCategory: null,
    );

    expect(book.title, '小熊绘本');
    expect(book.author, '张老师');
    expect(book.location, 'A架1层');
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
}
