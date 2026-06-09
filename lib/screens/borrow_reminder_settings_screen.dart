import 'package:flutter/material.dart';

import '../models/borrow_reminder_settings.dart';
import '../services/borrow_reminder_settings_service.dart';
import '../ui/widgets/async_action_button.dart';
import '../ui/widgets/section_card.dart';

class BorrowReminderSettingsScreen extends StatefulWidget {
  const BorrowReminderSettingsScreen({super.key});

  @override
  State<BorrowReminderSettingsScreen> createState() =>
      _BorrowReminderSettingsScreenState();
}

class _BorrowReminderSettingsScreenState
    extends State<BorrowReminderSettingsScreen> {
  final _service = BorrowReminderSettingsService();

  BorrowReminderSettings _settings = BorrowReminderSettings.defaults;
  bool _isLoading = true;
  AsyncActionState _saveState = AsyncActionState.idle;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final settings = await _service.getSettings();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _saveState = AsyncActionState.loading);
    try {
      await _service.saveSettings(_settings);
      if (!mounted) return;
      setState(() => _saveState = AsyncActionState.success);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('提醒设置已保存')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveState = AsyncActionState.error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    }
  }

  void _updateSettings(BorrowReminderSettings settings) {
    setState(() {
      _settings = settings;
      _saveState = AsyncActionState.idle;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('借阅提醒设置'),
        backgroundColor: Colors.blue.shade600,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStepperRow(
                          title: '全局即将到期',
                          subtitle: '仪表盘和即将到期列表使用该阈值',
                          value: _settings.dueSoonDays,
                          onChanged: (value) {
                            _updateSettings(
                              _settings.copyWith(dueSoonDays: value),
                            );
                          },
                        ),
                        const Divider(height: 24),
                        _buildStepperRow(
                          title: '幼儿借阅默认',
                          subtitle: '老师代学生办理借阅时默认提前提醒',
                          value: _settings.studentReminderDays,
                          onChanged: (value) {
                            _updateSettings(
                              _settings.copyWith(studentReminderDays: value),
                            );
                          },
                        ),
                        const Divider(height: 24),
                        _buildStepperRow(
                          title: '老师借阅默认',
                          subtitle: '老师或管理员本人借阅时默认提前提醒',
                          value: _settings.teacherReminderDays,
                          onChanged: (value) {
                            _updateSettings(
                              _settings.copyWith(teacherReminderDays: value),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AsyncActionButton(
                    onPressed: _saveSettings,
                    label: '保存设置',
                    successLabel: '已保存',
                    errorLabel: '重试保存',
                    icon: Icons.save_outlined,
                    state: _saveState,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStepperRow({
    required String title,
    required String subtitle,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: value <= 1 ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_circle_outline),
          tooltip: '减少天数',
        ),
        SizedBox(
          width: 54,
          child: Text(
            '$value 天',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          onPressed: value >= 30 ? null : () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
          tooltip: '增加天数',
        ),
      ],
    );
  }
}
