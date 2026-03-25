import '../api/shiti_api_client.dart';
import '../network/http_json_client.dart';
import '../../features/classes/class_workspace_data.dart';

abstract class ClassRepository {
  Future<List<ClassWorkspaceRecord>> listClasses({
    String? query,
    String? studentId,
    String? lessonId,
  });

  Future<ClassWorkspaceRecord?> getClass(String classId);
}

class FakeClassRepository implements ClassRepository {
  const FakeClassRepository(ShiTiApiClient apiClient);

  @override
  Future<List<ClassWorkspaceRecord>> listClasses({
    String? query,
    String? studentId,
    String? lessonId,
  }) async {
    final keyword = query?.trim().toLowerCase() ?? '';
    final normalizedStudentId = studentId?.trim();
    final normalizedLessonId = lessonId?.trim();
    return sampleClassRecords
        .where(
          (item) =>
              (keyword.isEmpty ||
                  item.name.toLowerCase().contains(keyword) ||
                  item.textbookLabel.toLowerCase().contains(keyword) ||
                  item.lessonFocusLabel.toLowerCase().contains(keyword) ||
                  item.focusLabel.toLowerCase().contains(keyword)) &&
              (normalizedStudentId == null ||
                  normalizedStudentId.isEmpty ||
                  item.focusStudentId == normalizedStudentId) &&
              (normalizedLessonId == null ||
                  normalizedLessonId.isEmpty ||
                  item.lessonId == normalizedLessonId),
        )
        .toList(growable: false);
  }

  @override
  Future<ClassWorkspaceRecord?> getClass(String classId) async {
    return findClassWorkspaceRecord(classId);
  }
}

class RemoteClassRepository implements ClassRepository {
  const RemoteClassRepository(this._client);

  final HttpJsonClient _client;

  @override
  Future<List<ClassWorkspaceRecord>> listClasses({
    String? query,
    String? studentId,
    String? lessonId,
  }) async {
    final requestQuery = <String, String>{};
    if (query != null && query.trim().isNotEmpty) {
      requestQuery['q'] = query.trim();
    }
    if (studentId != null && studentId.trim().isNotEmpty) {
      requestQuery['studentId'] = studentId.trim();
    }
    if (lessonId != null && lessonId.trim().isNotEmpty) {
      requestQuery['lessonId'] = lessonId.trim();
    }
    final response = await _client.getList(
      '/classes',
      query: requestQuery.isEmpty ? null : requestQuery,
      listKey: 'classes',
    );
    return response
        .whereType<Map>()
        .map((item) => ClassWorkspaceRecord.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<ClassWorkspaceRecord?> getClass(String classId) async {
    final response = await _client.getObject('/classes/$classId', objectKey: 'class');
    if (response.isEmpty) {
      return null;
    }
    return ClassWorkspaceRecord.fromJson(response);
  }
}
