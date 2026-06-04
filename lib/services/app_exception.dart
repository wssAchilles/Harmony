sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UnauthenticatedException extends AppException {
  const UnauthenticatedException() : super('用户未登录');
}

class InvalidRequestException extends AppException {
  const InvalidRequestException(super.message);
}

class InvalidBorrowQuantityException extends AppException {
  const InvalidBorrowQuantityException() : super('借阅数量必须大于0');
}

class InsufficientStockException extends AppException {
  const InsufficientStockException({
    required this.available,
    required this.requested,
  }) : super('库存不足，当前可借数量：$available，需要数量：$requested');

  final int available;
  final int requested;
}

class RecordNotFoundException extends AppException {
  const RecordNotFoundException(this.collection, this.id)
      : super('$collection 记录不存在: $id');

  final String collection;
  final Object id;
}

class BorrowRecordAlreadyReturnedException extends AppException {
  const BorrowRecordAlreadyReturnedException() : super('该图书已经归还');
}

class DeleteBlockedException extends AppException {
  const DeleteBlockedException(super.message);
}

class UnsupportedFeatureException extends AppException {
  const UnsupportedFeatureException(super.message);
}

String messageForError(Object error) {
  if (error is AppException) return error.message;
  final text = error.toString();
  const prefix = 'Exception: ';
  return text.startsWith(prefix) ? text.substring(prefix.length) : text;
}

Never throwServiceException(String context, Object error) {
  if (error is AppException) throw error;
  throw Exception('$context: ${messageForError(error)}');
}
