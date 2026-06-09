class BorrowReminderSettings {
  const BorrowReminderSettings({
    this.dueSoonDays = 3,
    this.studentReminderDays = 3,
    this.teacherReminderDays = 5,
  });

  static const defaults = BorrowReminderSettings();

  final int dueSoonDays;
  final int studentReminderDays;
  final int teacherReminderDays;

  int getDefaultReminderDays({required bool forStudent}) {
    return forStudent ? studentReminderDays : teacherReminderDays;
  }

  BorrowReminderSettings copyWith({
    int? dueSoonDays,
    int? studentReminderDays,
    int? teacherReminderDays,
  }) {
    return BorrowReminderSettings(
      dueSoonDays: _clampDays(dueSoonDays ?? this.dueSoonDays),
      studentReminderDays: _clampDays(
        studentReminderDays ?? this.studentReminderDays,
      ),
      teacherReminderDays: _clampDays(
        teacherReminderDays ?? this.teacherReminderDays,
      ),
    );
  }

  factory BorrowReminderSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    return BorrowReminderSettings(
      dueSoonDays: _asDays(json['due_soon_days'], defaults.dueSoonDays),
      studentReminderDays: _asDays(
        json['student_reminder_days'],
        defaults.studentReminderDays,
      ),
      teacherReminderDays: _asDays(
        json['teacher_reminder_days'],
        defaults.teacherReminderDays,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'due_soon_days': dueSoonDays,
      'student_reminder_days': studentReminderDays,
      'teacher_reminder_days': teacherReminderDays,
    };
  }
}

int _asDays(dynamic value, int fallback) {
  if (value is int) return _clampDays(value);
  if (value is num) return _clampDays(value.toInt());
  if (value is String) return _clampDays(int.tryParse(value) ?? fallback);
  return fallback;
}

int _clampDays(int value) => value.clamp(1, 30).toInt();
