import '../api/shiti_api_client.dart';
import '../network/http_json_client.dart';
import '../../features/lessons/lesson_workspace_data.dart';

abstract class LessonRepository {
  Future<List<LessonWorkspaceRecord>> listLessons({String? query});

  Future<LessonWorkspaceRecord?> getLesson(String lessonId);
}

class FakeLessonRepository implements LessonRepository {
  const FakeLessonRepository(ShiTiApiClient apiClient);

  @override
  Future<List<LessonWorkspaceRecord>> listLessons({String? query}) async {
    final keyword = query?.trim().toLowerCase() ?? '';
    if (keyword.isEmpty) {
      return sampleLessonRecords;
    }
    return sampleLessonRecords
        .where(
          (item) =>
              item.title.toLowerCase().contains(keyword) ||
              item.className.toLowerCase().contains(keyword) ||
              item.documentFocus.toLowerCase().contains(keyword) ||
              item.followUpLabel.toLowerCase().contains(keyword),
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
  Future<List<LessonWorkspaceRecord>> listLessons({String? query}) async {
    final response = await _client.getList(
      '/lessons',
      query: query != null && query.trim().isNotEmpty ? {'q': query.trim()} : null,
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
