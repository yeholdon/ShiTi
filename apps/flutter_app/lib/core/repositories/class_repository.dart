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

  Future<ClassWorkspaceRecord> createClass({
    required String name,
    required String stageLabel,
    required String teacherLabel,
    required String textbookLabel,
    String? focusLabel,
  });

  Future<ClassWorkspaceRecord> updateClass({
    required String classId,
    required String name,
    required String stageLabel,
    required String teacherLabel,
    required String textbookLabel,
    required String focusLabel,
    String? focusStudentId,
    String? focusStudentName,
    String? lessonId,
    String? lessonFocusLabel,
  });

  Future<void> deleteClass(String classId);
}

class FakeClassRepository implements ClassRepository {
  const FakeClassRepository(ShiTiApiClient apiClient);

  static final List<ClassWorkspaceRecord> _records =
      List<ClassWorkspaceRecord>.of(sampleClassRecords);

  @override
  Future<List<ClassWorkspaceRecord>> listClasses({
    String? query,
    String? studentId,
    String? lessonId,
  }) async {
    final keyword = query?.trim().toLowerCase() ?? '';
    final normalizedStudentId = studentId?.trim();
    final normalizedLessonId = lessonId?.trim();
    return _records
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
    try {
      return _records.firstWhere((item) => item.id == classId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ClassWorkspaceRecord> createClass({
    required String name,
    required String stageLabel,
    required String teacherLabel,
    required String textbookLabel,
    String? focusLabel,
  }) async {
    final created = ClassWorkspaceRecord(
      id: 'class-${_records.length + 1}',
      name: name,
      lessonId: '',
      documentId: '',
      focusStudentId: '',
      focusStudentName: '',
      stageLabel: stageLabel,
      teacherLabel: teacherLabel,
      textbookLabel: textbookLabel,
      focusLabel: focusLabel ?? '讲义整理',
      activityLabel: '新建档案',
      classSizeLabel: '0 人 · 待补充',
      lessonFocusLabel: '待安排课堂',
      structureInsight: '新建班级档案，等待补充学生、课堂时间线与资料联动。',
      studentCount: 0,
      weeklyLessonCount: 0,
      latestDocLabel: '暂无资料',
      assetLinks: const [],
      memberTiers: const [],
      lessonTimeline: const [],
      summary: '新建班级档案，等待补充成员、课堂安排与资料联动。',
      highlights: const ['已创建班级档案，可继续补充学生、课堂和资料。'],
      nextStep: '补充班级成员、安排第一堂课并关联资料。',
    );
    _records.insert(0, created);
    return created;
  }

  @override
  Future<ClassWorkspaceRecord> updateClass({
    required String classId,
    required String name,
    required String stageLabel,
    required String teacherLabel,
    required String textbookLabel,
    required String focusLabel,
    String? focusStudentId,
    String? focusStudentName,
    String? lessonId,
    String? lessonFocusLabel,
  }) async {
    final index = _records.indexWhere((item) => item.id == classId);
    if (index < 0) {
      throw StateError('Class not found');
    }
    final current = _records[index];
    final updated = ClassWorkspaceRecord(
      id: current.id,
      name: name,
      lessonId: lessonId ?? current.lessonId,
      documentId: current.documentId,
      focusStudentId: focusStudentId ?? current.focusStudentId,
      focusStudentName: focusStudentName ?? current.focusStudentName,
      stageLabel: stageLabel,
      teacherLabel: teacherLabel,
      textbookLabel: textbookLabel,
      focusLabel: focusLabel,
      activityLabel: current.activityLabel,
      classSizeLabel: current.classSizeLabel,
      lessonFocusLabel: lessonFocusLabel ?? current.lessonFocusLabel,
      structureInsight: current.structureInsight,
      studentCount: current.studentCount,
      weeklyLessonCount: current.weeklyLessonCount,
      latestDocLabel: current.latestDocLabel,
      assetLinks: current.assetLinks,
      memberTiers: current.memberTiers,
      lessonTimeline: current.lessonTimeline,
      summary: current.summary,
      highlights: current.highlights,
      nextStep: current.nextStep,
    );
    _records[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteClass(String classId) async {
    _records.removeWhere((item) => item.id == classId);
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

  @override
  Future<ClassWorkspaceRecord> createClass({
    required String name,
    required String stageLabel,
    required String teacherLabel,
    required String textbookLabel,
    String? focusLabel,
  }) async {
    final response = await _client.postObject(
      '/classes',
      body: {
        'name': name,
        'stageLabel': stageLabel,
        'teacherLabel': teacherLabel,
        'textbookLabel': textbookLabel,
        if (focusLabel != null && focusLabel.trim().isNotEmpty)
          'focusLabel': focusLabel.trim(),
      },
    );
    return ClassWorkspaceRecord.fromJson(response['class'] as Map<String, dynamic>);
  }

  @override
  Future<ClassWorkspaceRecord> updateClass({
    required String classId,
    required String name,
    required String stageLabel,
    required String teacherLabel,
    required String textbookLabel,
    required String focusLabel,
    String? focusStudentId,
    String? focusStudentName,
    String? lessonId,
    String? lessonFocusLabel,
  }) async {
    final response = await _client.patchObject(
      '/classes/$classId',
      body: {
        'name': name,
        'stageLabel': stageLabel,
        'teacherLabel': teacherLabel,
        'textbookLabel': textbookLabel,
        'focusLabel': focusLabel,
        'focusStudentId': focusStudentId ?? '',
        'focusStudentName': focusStudentName ?? '',
        'lessonId': lessonId ?? '',
        'lessonFocusLabel': lessonFocusLabel ?? '',
      },
    );
    return ClassWorkspaceRecord.fromJson(response['class'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteClass(String classId) async {
    await _client.deleteObject('/classes/$classId');
  }
}
