import '../api/shiti_api_client.dart';
import '../network/http_json_client.dart';
import '../../features/students/student_workspace_data.dart';

abstract class StudentRepository {
  Future<List<StudentWorkspaceRecord>> listStudents({String? query});

  Future<StudentWorkspaceRecord?> getStudent(String studentId);
}

class FakeStudentRepository implements StudentRepository {
  const FakeStudentRepository(ShiTiApiClient apiClient);

  @override
  Future<List<StudentWorkspaceRecord>> listStudents({String? query}) async {
    final keyword = query?.trim().toLowerCase() ?? '';
    if (keyword.isEmpty) {
      return sampleStudentRecords;
    }
    return sampleStudentRecords
        .where(
          (student) =>
              student.name.toLowerCase().contains(keyword) ||
              student.className.toLowerCase().contains(keyword) ||
              student.textbookLabel.toLowerCase().contains(keyword) ||
              student.habitTag.toLowerCase().contains(keyword),
        )
        .toList(growable: false);
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
  Future<List<StudentWorkspaceRecord>> listStudents({String? query}) async {
    final response = await _client.getList(
      '/students',
      query: query != null && query.trim().isNotEmpty ? {'q': query.trim()} : null,
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
