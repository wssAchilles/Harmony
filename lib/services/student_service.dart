import '../utils/app_logger.dart';

import '../models/student.dart';
import 'app_exception.dart';
import 'backend/backend_gateway.dart';
import 'backend/pb_mapper.dart';

/// 学生数据服务层
class StudentService {
  static final StudentService _instance = StudentService._internal();
  factory StudentService() => _instance;
  StudentService._internal({BackendGateway? backend})
      : _backend = backend ?? backendGateway;

  StudentService.withBackend(BackendGateway backend) : _backend = backend;

  final BackendGateway _backend;

  Stream<List<Student>> getStudentsStream() {
    return _backend.pollingListStream(getAllStudents);
  }

  Future<List<Student>> getAllStudents() async {
    try {
      final records = await _backend.getFullList(
        'students',
        sort: 'class_name,full_name',
      );
      return records
          .map((record) => Student.fromJson(recordToJson(record)))
          .toList();
    } catch (e) {
      AppLogger.warning('获取学生列表失败: $e');
      rethrow;
    }
  }

  Future<List<Student>> getStudentsByClass(String className) async {
    try {
      final records = await _backend.getFullList(
        'students',
        filter: 'class_name = "${escapeFilterValue(className)}"',
        sort: 'full_name',
      );
      return records
          .map((record) => Student.fromJson(recordToJson(record)))
          .toList();
    } catch (e) {
      AppLogger.warning('按班级获取学生失败: $e');
      rethrow;
    }
  }

  Future<List<Student>> searchStudents(String query) async {
    try {
      final keyword = escapeFilterValue(query);
      final records = await _backend.getFullList(
        'students',
        filter: 'full_name ~ "$keyword" || class_name ~ "$keyword"',
        sort: 'class_name,full_name',
      );
      return records
          .map((record) => Student.fromJson(recordToJson(record)))
          .toList();
    } catch (e) {
      AppLogger.warning('搜索学生失败: $e');
      rethrow;
    }
  }

  Future<Student?> getStudentById(int id) async {
    try {
      final record = await _backend.findByNumericId('students', id);
      if (record == null) return null;
      return Student.fromJson(recordToJson(record));
    } catch (e) {
      AppLogger.warning('获取学生详情失败: $e');
      rethrow;
    }
  }

  Future<void> addStudent(Student student) async {
    try {
      await _backend.create(
        'students',
        {
          'id': numericRecordId(await _backend.nextNumericId('students')),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'full_name': student.fullName,
          'class_name': student.className,
        },
      );
    } catch (e) {
      AppLogger.warning('添加学生失败: $e');
      rethrow;
    }
  }

  Future<void> updateStudent(Student student) async {
    if (student.id == null) {
      throw const InvalidRequestException('无法更新没有ID的学生');
    }

    try {
      final recordId = await _backend.requireRecordIdByNumericId(
        'students',
        student.id!,
      );
      await _backend.update(
        'students',
        recordId,
        {
          'full_name': student.fullName,
          'class_name': student.className,
        },
      );
    } catch (e) {
      AppLogger.warning('更新学生失败: $e');
      rethrow;
    }
  }

  Future<void> deleteStudent(int studentId) async {
    try {
      final borrowRecords = await _backend.getFullList(
        'borrow_records',
        filter: 'student_id = $studentId && return_date = null',
        fields: 'id',
      );

      if (borrowRecords.isNotEmpty) {
        throw const DeleteBlockedException('该学生还有未归还的图书，无法删除');
      }

      final recordId =
          await _backend.requireRecordIdByNumericId('students', studentId);
      await _backend.delete('students', recordId);
    } catch (e) {
      AppLogger.warning('删除学生失败: $e');
      rethrow;
    }
  }

  Future<List<String>> getAllClasses() async {
    try {
      final students = await getAllStudents();
      final classes = students
          .map((student) => student.className)
          .whereType<String>()
          .where((className) => className.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return classes;
    } catch (e) {
      AppLogger.warning('获取班级列表失败: $e');
      return [];
    }
  }

  Future<void> importStudents(List<Student> students) async {
    try {
      for (final student in students) {
        await addStudent(student);
      }
    } catch (e) {
      AppLogger.warning('批量导入学生失败: $e');
      rethrow;
    }
  }
}
