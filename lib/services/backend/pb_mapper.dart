import 'package:pocketbase/pocketbase.dart';

Map<String, dynamic> recordToJson(RecordModel record) {
  final data = Map<String, dynamic>.from(record.toJson());
  final sourceId = data['source_id'];
  if (sourceId is String && sourceId.isNotEmpty) {
    data['id'] = sourceId;
  } else {
    data['id'] = _numericIdFromRecordId(record.id) ?? record.id;
  }
  return data;
}

int? asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String && value.isNotEmpty) return int.tryParse(value);
  return null;
}

int asInt(dynamic value, {int fallback = 0}) {
  return asNullableInt(value) ?? fallback;
}

String? asNullableString(dynamic value) {
  if (value == null) return null;
  final stringValue = value.toString();
  return stringValue.isEmpty ? null : stringValue;
}

DateTime? asNullableDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

String? dateForPocketBase(DateTime? value) {
  return value?.toUtc().toIso8601String();
}

String escapeFilterValue(String value) {
  return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
}

String numericRecordId(int id) {
  return id.toString().padLeft(15, '0');
}

int? _numericIdFromRecordId(String id) {
  if (RegExp(r'^\d{15}$').hasMatch(id)) {
    return int.tryParse(id);
  }
  return null;
}
