import 'package:pocketbase/pocketbase.dart';

import '../models/borrow_reminder_settings.dart';
import '../utils/app_logger.dart';
import 'backend/backend_gateway.dart';
import 'backend/pb_mapper.dart';

class BorrowReminderSettingsService {
  BorrowReminderSettingsService({BackendGateway? backend})
      : _backend = backend ?? backendGateway;

  static const settingKey = 'borrow_reminder_settings';

  final BackendGateway _backend;

  Future<BorrowReminderSettings> getSettings() async {
    try {
      final record = await _backend.getFirstListItem(
        'app_settings',
        'key = "$settingKey"',
      );
      final value = recordToJson(record)['value'];
      return BorrowReminderSettings.fromJson(
        value is Map ? Map<String, dynamic>.from(value) : null,
      );
    } on ClientException catch (error) {
      if (error.statusCode == 404) {
        return BorrowReminderSettings.defaults;
      }
      AppLogger.warning('读取借阅提醒设置失败: $error');
      return BorrowReminderSettings.defaults;
    } catch (error) {
      AppLogger.warning('读取借阅提醒设置失败: $error');
      return BorrowReminderSettings.defaults;
    }
  }

  Future<void> saveSettings(BorrowReminderSettings settings) async {
    final body = {
      'key': settingKey,
      'value': settings.toJson(),
      'updated_at': dateForPocketBase(DateTime.now()),
    };

    try {
      final record = await _backend.getFirstListItem(
        'app_settings',
        'key = "$settingKey"',
      );
      await _backend.update('app_settings', record.id, body);
    } on ClientException catch (error) {
      if (error.statusCode == 404) {
        await _backend.create('app_settings', body);
        return;
      }
      rethrow;
    }
  }
}
