import '../api/shiti_api_client.dart';
import '../network/http_json_client.dart';
import '../../features/classes/class_workspace_data.dart';

abstract class ClassRepository {
  Future<List<ClassWorkspaceRecord>> listClasses({String? query});

  Future<ClassWorkspaceRecord?> getClass(String classId);
}

class FakeClassRepository implements ClassRepository {
  const FakeClassRepository(ShiTiApiClient apiClient);

  @override
  Future<List<ClassWorkspaceRecord>> listClasses({String? query}) async {
    final keyword = query?.trim().toLowerCase() ?? '';
    if (keyword.isEmpty) {
      return sampleClassRecords;
    }
    return sampleClassRecords
        .where(
          (item) =>
              item.name.toLowerCase().contains(keyword) ||
              item.textbookLabel.toLowerCase().contains(keyword) ||
              item.lessonFocusLabel.toLowerCase().contains(keyword) ||
              item.focusLabel.toLowerCase().contains(keyword),
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
  Future<List<ClassWorkspaceRecord>> listClasses({String? query}) async {
    final response = await _client.getList(
      '/classes',
      query: query != null && query.trim().isNotEmpty ? {'q': query.trim()} : null,
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
