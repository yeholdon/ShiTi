import '../api/shiti_api_client.dart';
import '../network/http_json_client.dart';
import '../../features/students/student_workspace_data.dart';

abstract class StudentRepository {
  Future<List<StudentWorkspaceRecord>> listStudents({
    String? query,
    String? classId,
    String? lessonId,
  });

  Future<StudentWorkspaceRecord?> getStudent(String studentId);
}

class FakeStudentRepository implements StudentRepository {
  const FakeStudentRepository(ShiTiApiClient apiClient);

  @override
  Future<List<StudentWorkspaceRecord>> listStudents({
    String? query,
    String? classId,
    String? lessonId,
  }) async {
    final keyword = query?.trim().toLowerCase() ?? '';
    final normalizedClassId = classId?.trim();
    final normalizedLessonId = lessonId?.trim();
    return sampleStudentRecords.where((student) {
      final matchesKeyword =
          keyword.isEmpty ||
          student.name.toLowerCase().contains(keyword) ||
          student.className.toLowerCase().contains(keyword) ||
          student.textbookLabel.toLowerCase().contains(keyword) ||
          student.habitTag.toLowerCase().contains(keyword);
      final matchesClass = normalizedClassId == null ||
          normalizedClassId.isEmpty ||
          student.classId == normalizedClassId;
      final matchesLesson = normalizedLessonId == null ||
          normalizedLessonId.isEmpty ||
          student.lessonId == normalizedLessonId;
      return matchesKeyword && matchesClass && matchesLesson;
    }).toList(growable: false);
  }

  @override
  Future<StudentWorkspaceRecord?> getStudent(String studentId) async {
    return findStudentWorkspaceRecord(studentId);
  }
}

class RemoteStudentRepository implements StudentRepository {
  const RemoteStudentRepository(this._client);

  final HttpJsonClient _client;

  @override
  Future<List<StudentWorkspaceRecord>> listStudents({
    String? query,
    String? classId,
    String? lessonId,
  }) async {
    final requestQuery = <String, String>{};
    if (query != null && query.trim().isNotEmpty) {
      requestQuery['q'] = query.trim();
    }
    if (classId != null && classId.trim().isNotEmpty) {
      requestQuery['classId'] = classId.trim();
    }
    if (lessonId != null && lessonId.trim().isNotEmpty) {
      requestQuery['lessonId'] = lessonId.trim();
    }
    final response = await _client.getList(
      '/students',
      query: requestQuery.isEmpty ? null : requestQuery,
      listKey: 'students',
    );
    return response
        .whereType<Map>()
        .map((item) => StudentWorkspaceRecord.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<StudentWorkspaceRecord?> getStudent(String studentId) async {
    final response = await _client.getObject('/students/$studentId', objectKey: 'student');
    if (response.isEmpty) {
      return null;
    }
    return StudentWorkspaceRecord.fromJson(response);
  }
}
