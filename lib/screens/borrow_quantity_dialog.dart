import 'package:flutter/material.dart';

class BorrowQuantityResult {
  const BorrowQuantityResult({required this.quantity});

  final int quantity;
}

class BorrowQuantityDialog extends StatefulWidget {
  const BorrowQuantityDialog({
    super.key,
    required this.title,
    required this.availableQuantity,
    required this.confirmLabel,
    this.description,
    this.details = const [],
  });

  final String title;
  final String? description;
  final List<String> details;
  final int availableQuantity;
  final String confirmLabel;

  @override
  State<BorrowQuantityDialog> createState() => _BorrowQuantityDialogState();
}

class _BorrowQuantityDialogState extends State<BorrowQuantityDialog> {
  int _selectedQuantity = 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.description != null) ...[
            Text(widget.description!),
            const SizedBox(height: 8),
          ],
          ...widget.details.map(
            (detail) => Text(detail, style: TextStyle(color: Colors.grey[600])),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Flexible(
                child: Text(
                  '借阅数量：',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: _selectedQuantity > 1
                    ? () => setState(() => _selectedQuantity--)
                    : null,
                icon: const Icon(Icons.remove, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.grey[700],
                ),
              ),
              Container(
                width: 40,
                alignment: Alignment.center,
                child: Text(
                  '$_selectedQuantity',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: _selectedQuantity < widget.availableQuantity
                    ? () => setState(() => _selectedQuantity++)
                    : null,
                icon: const Icon(Icons.add, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue[100],
                  foregroundColor: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              '可借数量：${widget.availableQuantity} 本',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            BorrowQuantityResult(quantity: _selectedQuantity),
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
