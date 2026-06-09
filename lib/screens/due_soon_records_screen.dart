import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/dashboard_data.dart';
import '../services/borrow_reminder_settings_service.dart';
import '../services/dashboard_service.dart';
import '../ui/widgets/empty_state_view.dart';
import '../ui/widgets/section_card.dart';
import '../ui/widgets/status_chip.dart';

class DueSoonRecordsScreen extends StatefulWidget {
  const DueSoonRecordsScreen({super.key});

  @override
  State<DueSoonRecordsScreen> createState() => _DueSoonRecordsScreenState();
}

class _DueSoonRecordsScreenState extends State<DueSoonRecordsScreen> {
  final DashboardService _dashboardService = DashboardService();
  final BorrowReminderSettingsService _settingsService =
      BorrowReminderSettingsService();
  List<OverdueBorrowRecordView> _records = [];
  int _withinDays = 3;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _settingsService.getSettings();
      final records = await _dashboardService.getDueSoonRecords();
      if (!mounted) return;
      setState(() {
        _records = records;
        _withinDays = settings.dueSoonDays;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载即将到期记录失败: $e')));
    }
  }

  int _daysLeft(DateTime dueDate) {
    return dueDate.difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('即将到期图书'),
        backgroundColor: Colors.amber.shade700,
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecords,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _records.isEmpty
                ? EmptyStateView(
                    icon: Icons.event_available,
                    title: '暂无即将到期的图书',
                    message: '$_withinDays天内到期的未还图书会显示在这里',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      return _buildRecordCard(_records[index]);
                    },
                  ),
      ),
    );
  }

  Widget _buildRecordCard(OverdueBorrowRecordView record) {
    final dueDate = record.dueDate;
    final daysLeft = dueDate == null ? 0 : _daysLeft(dueDate);
    final statusText = daysLeft <= 0 ? '今日到期' : '剩余 $daysLeft 天';

    return SectionCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.bookTitle ?? '未知图书',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusChip(
                label: statusText,
                backgroundColor: Colors.amber[100]!,
                foregroundColor: Colors.amber[900]!,
                icon: Icons.schedule,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '借阅人: ${record.borrowerName} (${record.borrowerType})',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(
            '借阅日期: ${DateFormat('yyyy-MM-dd').format(record.borrowDate)}',
            style: TextStyle(color: Colors.grey[700]),
          ),
          if (dueDate != null) ...[
            const SizedBox(height: 4),
            Text(
              '应还日期: ${DateFormat('yyyy-MM-dd').format(dueDate)}',
              style: TextStyle(color: Colors.amber[900]),
            ),
          ],
        ],
      ),
    );
  }
}
