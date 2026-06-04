import '../models/borrow_record.dart';

class ProfileBorrowSummary {
  const ProfileBorrowSummary({required this.activeBorrows});

  const ProfileBorrowSummary.empty() : activeBorrows = const [];

  final List<BorrowRecord> activeBorrows;

  int get totalQuantity {
    return activeBorrows.fold<int>(0, (sum, record) => sum + record.quantity);
  }
}
