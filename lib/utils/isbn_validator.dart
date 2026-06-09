class IsbnValidator {
  const IsbnValidator._();

  static String normalize(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]+'), '');
  }

  static bool isValid(String value) {
    final isbn = normalize(value);
    if (isbn.isEmpty) return true;
    if (isbn.length == 10) return _isValidIsbn10(isbn);
    if (isbn.length == 13) return _isValidIsbn13(isbn);
    return false;
  }

  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return isValid(value) ? null : '请输入有效的 ISBN-10 或 ISBN-13';
  }

  static bool _isValidIsbn10(String isbn) {
    if (!RegExp(r'^\d{9}[\dX]$').hasMatch(isbn)) return false;
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      final char = isbn[i];
      final digit = char == 'X' ? 10 : int.parse(char);
      sum += digit * (10 - i);
    }
    return sum % 11 == 0;
  }

  static bool _isValidIsbn13(String isbn) {
    if (!RegExp(r'^\d{13}$').hasMatch(isbn)) return false;
    var sum = 0;
    for (var i = 0; i < 13; i++) {
      final digit = int.parse(isbn[i]);
      sum += i.isEven ? digit : digit * 3;
    }
    return sum % 10 == 0;
  }
}
