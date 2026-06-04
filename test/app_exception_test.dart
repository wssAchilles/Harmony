import 'package:flutter_test/flutter_test.dart';
import 'package:kindergarten_library/services/app_exception.dart';

void main() {
  test('uses stable message for app exceptions', () {
    const error = InsufficientStockException(available: 1, requested: 3);

    expect(messageForError(error), '库存不足，当前可借数量：1，需要数量：3');
    expect(error.toString(), '库存不足，当前可借数量：1，需要数量：3');
  });

  test('strips generic Exception prefix for UI display', () {
    final error = Exception('保存失败');

    expect(messageForError(error), '保存失败');
  });
}
