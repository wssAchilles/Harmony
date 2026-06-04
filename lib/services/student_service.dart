import '../models/student.dart';
import 'backend/pb_mapper.dart';
import 'backend/pocketbase_client.dart';

/// 学生数据服务层
class StudentService {
  static final StudentService _instance = StudentService._internal();
  factory StudentService() => _instance;
  StudentService._internal();

  Stream<List<Student>> getStudentsStream() {
    return pollingListStream(getAllStudents);
  }

  Future<List<Student>> getAllStudents() async {
    try {
      final records = await pb
          .collection('students')
          .getFullList(sort: 'class_name,full_name');
      return records
          .map((record) => Student.fromJson(recordToJson(record)))
          .toList();
    } catch (e) {
      print('获取学生列表失败: $e');
      rethrow;
    }
  }

  Future<List<Student>> getStudentsByClass(String className) async {
    try {
      final records = await pb
          .collection('students')
          .getFullList(
            filter: 'class_name = "${escapeFilterValue(className)}"',
            sort: 'full_name',
          );
      return records
          .map((record) => Student.fromJson(recordToJson(record)))
          .toList();
    } catch (e) {
      print('按班级获取学生失败: $e');
      rethrow;
    }
  }

  Future<List<Student>> searchStudents(String query) async {
    try {
      final keyword = escapeFilterValue(query);
      final records = await pb
          .collection('students')
          .getFullList(
            filter: 'full_name ~ "$keyword" || class_name ~ "$keyword"',
            sort: 'class_name,full_name',
          );
      return records
          .map((record) => Student.fromJson(recordToJson(record)))
          .toList();
    } catch (e) {
      print('搜索学生失败: $e');
      rethrow;
    }
  }

  Future<Student?> getStudentById(int id) async {
    try {
      final record = await findByNumericId('students', id);
      if (record == null) return null;
      return Student.fromJson(recordToJson(record));
    } catch (e) {
      print('获取学生详情失败: $e');
      rethrow;
    }
  }

  Future<void> addStudent(Student student) async {
    try {
      await pb
          .collection('students')
          .create(
            body: {
              'id': numericRecordId(await nextNumericId('students')),
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'full_name': student.fullName,
              'class_name': student.className,
            },
          );
    } catch (e) {
      print('添加学生失败: $e');
      rethrow;
    }
  }

  Future<void> updateStudent(Student student) async {
    if (student.id == null) {
      throw Exception('无法更新没有ID的学生');
    }

    try {
      final recordId = await requireRecordIdByNumericId(
        'students',
        student.id!,
      );
      await pb
          .collection('students')
          .update(
            recordId,
            body: {
              'full_name': student.fullName,
              'class_name': student.className,
            },
          );
    } catch (e) {
      print('更新学生失败: $e');
      rethrow;
    }
  }

  Future<void> deleteStudent(int studentId) async {
    try {
      final borrowRecords = await pb
          .collection('borrow_records')
          .getFullList(
            filter: 'student_id = $studentId && return_date = null',
            fields: 'id',
          );

      if (borrowRecords.isNotEmpty) {
        throw Exception('该学生还有未归还的图书，无法删除');
      }

      final recordId = await requireRecordIdByNumericId('students', studentId);
      await pb.collection('students').delete(recordId);
    } catch (e) {
      print('删除学生失败: $e');
      rethrow;
    }
  }

  Future<List<String>> getAllClasses() async {
    try {
      final students = await getAllStudents();
      final classes =
          students
              .map((student) => student.className)
              .whereType<String>()
              .where((className) => className.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      return classes;
    } catch (e) {
      print('获取班级列表失败: $e');
      return [];
    }
  }

  Future<void> importStudents(List<Student> students) async {
    try {
      for (final student in students) {
        await addStudent(student);
      }
    } catch (e) {
      print('批量导入学生失败: $e');
      rethrow;
    }
  }
}
