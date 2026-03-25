import '../api/shiti_api_client.dart';
import '../network/http_json_client.dart';
import '../../features/lessons/lesson_workspace_data.dart';

abstract class LessonRepository {
  Future<List<LessonWorkspaceRecord>> listLessons({
    String? query,
    String? studentId,
    String? classId,
  });

  Future<LessonWorkspaceRecord?> getLesson(String lessonId);
}

class FakeLessonRepository implements LessonRepository {
  const FakeLessonRepository(ShiTiApiClient apiClient);

  @override
  Future<List<LessonWorkspaceRecord>> listLessons({
    String? query,
    String? studentId,
    String? classId,
  }) async {
    final keyword = query?.trim().toLowerCase() ?? '';
    final normalizedStudentId = studentId?.trim();
    final normalizedClassId = classId?.trim();
    return sampleLessonRecords
        .where(
          (item) =>
              (keyword.isEmpty ||
                  item.title.toLowerCase().contains(keyword) ||
                  item.className.toLowerCase().contains(keyword) ||
                  item.documentFocus.toLowerCase().contains(keyword) ||
                  item.followUpLabel.toLowerCase().contains(keyword)) &&
              (normalizedStudentId == null ||
                  normalizedStudentId.isEmpty ||
                  item.focusStudentId == normalizedStudentId) &&
              (normalizedClassId == null ||
                  normalizedClassId.isEmpty ||
                  item.classId == normalizedClassId),
        )
        .toList(growable: false);
  }

  @override
  Future<LessonWorkspaceRecord?> getLesson(String lessonId) async {
    return findLessonWorkspaceRecord(lessonId);
  }
}

class RemoteLessonRepository implements LessonRepository {
  const RemoteLessonRepository(this._client);

  final HttpJsonClient _client;

  @override
  Future<List<LessonWorkspaceRecord>> listLessons({
    String? query,
    String? studentId,
    String? classId,
  }) async {
    final requestQuery = <String, String>{};
    if (query != null && query.trim().isNotEmpty) {
      requestQuery['q'] = query.trim();
    }
    if (studentId != null && studentId.trim().isNotEmpty) {
      requestQuery['studentId'] = studentId.trim();
    }
    if (classId != null && classId.trim().isNotEmpty) {
      requestQuery['classId'] = classId.trim();
    }
    final response = await _client.getList(
      '/lessons',
      query: requestQuery.isEmpty ? null : requestQuery,
      listKey: 'lessons',
    );
    return response
        .whereType<Map>()
        .map((item) => LessonWorkspaceRecord.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<LessonWorkspaceRecord?> getLesson(String lessonId) async {
    final response = await _client.getObject('/lessons/$lessonId', objectKey: 'lesson');
    if (response.isEmpty) {
      return null;
    }
    return LessonWorkspaceRecord.fromJson(response);
  }
}
