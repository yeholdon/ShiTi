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

  Future<LessonWorkspaceRecord> createLesson({
    required String title,
    required String teacherLabel,
    required String scheduleLabel,
    String? classScopeLabel,
  });

  Future<LessonWorkspaceRecord> updateLesson({
    required String lessonId,
    required String title,
    required String teacherLabel,
    required String scheduleLabel,
    required String classScopeLabel,
    String? focusStudentId,
    String? focusStudentName,
    String? classId,
    String? documentId,
    String? documentFocus,
    List<String>? feedbackStudentIds,
  });

  Future<void> deleteLesson(String lessonId);

  Future<LessonWorkspaceRecord> setLessonArchived(
    String lessonId, {
    required bool archived,
  });
}

class FakeLessonRepository implements LessonRepository {
  const FakeLessonRepository(ShiTiApiClient apiClient);

  static final List<LessonWorkspaceRecord> _records =
      List<LessonWorkspaceRecord>.of(sampleLessonRecords);

  @override
  Future<List<LessonWorkspaceRecord>> listLessons({
    String? query,
    String? studentId,
    String? classId,
  }) async {
    final keyword = query?.trim().toLowerCase() ?? '';
    final normalizedStudentId = studentId?.trim();
    final normalizedClassId = classId?.trim();
    return _records
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
                  item.classId == normalizedClassId) &&
              !item.isArchived,
        )
        .toList(growable: false);
  }

  @override
  Future<LessonWorkspaceRecord?> getLesson(String lessonId) async {
    try {
      return _records.firstWhere((item) => item.id == lessonId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<LessonWorkspaceRecord> createLesson({
    required String title,
    required String teacherLabel,
    required String scheduleLabel,
    String? classScopeLabel,
  }) async {
    final created = LessonWorkspaceRecord(
      id: 'lesson-${_records.length + 1}',
      title: title,
      classId: '',
      className: classScopeLabel == '未绑定班级' ? '' : (classScopeLabel ?? ''),
      focusStudentId: '',
      focusStudentName: '',
      teacherLabel: teacherLabel,
      scheduleLabel: scheduleLabel,
      scheduleTag: '待安排',
      classScopeLabel: classScopeLabel ?? '未绑定班级',
      documentFocus: '未绑定资料',
      documentId: '',
      feedbackStatus: '待回收',
      followUpLabel: '待安排',
      feedbackInsight: '新建课堂档案，等待补充资料、反馈明细与课后任务。',
      feedbackRecords: const [],
      assetRecords: const [],
      taskRecords: const [],
      summary: '新建课堂档案，等待补充班级、资料和课后反馈。',
      highlights: const ['已创建课堂档案，可继续补充班级、资料与反馈任务。'],
      nextStep: '绑定班级、安排主资料并补充首轮课后反馈。',
      archivedAt: null,
    );
    _records.insert(0, created);
    return created;
  }

  @override
  Future<LessonWorkspaceRecord> updateLesson({
    required String lessonId,
    required String title,
    required String teacherLabel,
    required String scheduleLabel,
    required String classScopeLabel,
    String? focusStudentId,
    String? focusStudentName,
    String? classId,
    String? documentId,
    String? documentFocus,
    List<String>? feedbackStudentIds,
  }) async {
    final index = _records.indexWhere((item) => item.id == lessonId);
    if (index < 0) {
      throw StateError('Lesson not found');
    }
    final current = _records[index];
    final updated = LessonWorkspaceRecord(
      id: current.id,
      title: title,
      classId: classId ?? current.classId,
      className: classScopeLabel == '未绑定班级' ? '' : classScopeLabel,
      focusStudentId: focusStudentId ?? current.focusStudentId,
      focusStudentName: focusStudentName ?? current.focusStudentName,
      teacherLabel: teacherLabel,
      scheduleLabel: scheduleLabel,
      scheduleTag: current.scheduleTag,
      classScopeLabel: classScopeLabel,
      documentFocus: documentFocus ?? current.documentFocus,
      documentId: documentId ?? current.documentId,
      feedbackStatus: feedbackStudentIds == null
          ? current.feedbackStatus
          : feedbackStudentIds.isEmpty
              ? '待回收'
              : '${feedbackStudentIds.length} 人已承接',
      followUpLabel: current.followUpLabel,
      feedbackInsight: current.feedbackInsight,
      feedbackRecords: current.feedbackRecords,
      assetRecords: current.assetRecords,
      taskRecords: current.taskRecords,
      summary: current.summary,
      highlights: current.highlights,
      nextStep: current.nextStep,
      archivedAt: current.archivedAt,
    );
    _records[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteLesson(String lessonId) async {
    _records.removeWhere((item) => item.id == lessonId);
  }

  @override
  Future<LessonWorkspaceRecord> setLessonArchived(
    String lessonId, {
    required bool archived,
  }) async {
    final index = _records.indexWhere((item) => item.id == lessonId);
    if (index < 0) {
      throw StateError('Lesson not found');
    }
    final current = _records[index];
    final updated = LessonWorkspaceRecord(
      id: current.id,
      title: current.title,
      classId: current.classId,
      className: current.className,
      focusStudentId: current.focusStudentId,
      focusStudentName: current.focusStudentName,
      teacherLabel: current.teacherLabel,
      scheduleLabel: current.scheduleLabel,
      scheduleTag: current.scheduleTag,
      classScopeLabel: current.classScopeLabel,
      documentFocus: current.documentFocus,
      documentId: current.documentId,
      feedbackStatus: current.feedbackStatus,
      followUpLabel: current.followUpLabel,
      feedbackInsight: current.feedbackInsight,
      feedbackRecords: current.feedbackRecords,
      assetRecords: current.assetRecords,
      taskRecords: current.taskRecords,
      summary: current.summary,
      highlights: current.highlights,
      nextStep: current.nextStep,
      archivedAt: archived ? (current.archivedAt ?? DateTime.now()) : null,
    );
    _records[index] = updated;
    return updated;
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
        .map((item) =>
            LessonWorkspaceRecord.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<LessonWorkspaceRecord?> getLesson(String lessonId) async {
    final response =
        await _client.getObject('/lessons/$lessonId', objectKey: 'lesson');
    if (response.isEmpty) {
      return null;
    }
    return LessonWorkspaceRecord.fromJson(response);
  }

  @override
  Future<LessonWorkspaceRecord> createLesson({
    required String title,
    required String teacherLabel,
    required String scheduleLabel,
    String? classScopeLabel,
  }) async {
    final response = await _client.postObject(
      '/lessons',
      body: {
        'title': title,
        'teacherLabel': teacherLabel,
        'scheduleLabel': scheduleLabel,
        if (classScopeLabel != null && classScopeLabel.trim().isNotEmpty)
          'classScopeLabel': classScopeLabel.trim(),
      },
    );
    return LessonWorkspaceRecord.fromJson(
        response['lesson'] as Map<String, dynamic>);
  }

  @override
  Future<LessonWorkspaceRecord> updateLesson({
    required String lessonId,
    required String title,
    required String teacherLabel,
    required String scheduleLabel,
    required String classScopeLabel,
    String? focusStudentId,
    String? focusStudentName,
    String? classId,
    String? documentId,
    String? documentFocus,
    List<String>? feedbackStudentIds,
  }) async {
    final response = await _client.patchObject(
      '/lessons/$lessonId',
      body: {
        'title': title,
        'teacherLabel': teacherLabel,
        'scheduleLabel': scheduleLabel,
        'classScopeLabel': classScopeLabel,
        'focusStudentId': focusStudentId ?? '',
        'focusStudentName': focusStudentName ?? '',
        'classId': classId ?? '',
        'documentId': documentId ?? '',
        'documentFocus': documentFocus ?? '',
        if (feedbackStudentIds != null)
          'feedbackStudentIds': feedbackStudentIds,
      },
    );
    return LessonWorkspaceRecord.fromJson(
        response['lesson'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteLesson(String lessonId) async {
    await _client.deleteObject('/lessons/$lessonId');
  }

  @override
  Future<LessonWorkspaceRecord> setLessonArchived(
    String lessonId, {
    required bool archived,
  }) async {
    final response = await _client.patchObject(
      '/lessons/$lessonId',
      body: {'archived': archived},
    );
    return LessonWorkspaceRecord.fromJson(
      response['lesson'] as Map<String, dynamic>,
    );
  }
}
