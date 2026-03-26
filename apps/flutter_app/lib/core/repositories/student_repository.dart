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

  Future<StudentWorkspaceRecord> createStudent({
    required String name,
    required String gradeLabel,
    required String subjectLabel,
    required String textbookLabel,
    String? classId,
    String? className,
    String? lessonId,
    String? documentId,
    String? documentName,
  });

  Future<StudentWorkspaceRecord> updateStudent({
    required String studentId,
    required String name,
    required String gradeLabel,
    required String subjectLabel,
    required String textbookLabel,
    String? classId,
    String? className,
    String? lessonId,
    String? documentId,
    String? documentName,
  });

  Future<void> deleteStudent(String studentId);

  Future<StudentWorkspaceRecord> setStudentArchived(
    String studentId, {
    required bool archived,
  });
}

class FakeStudentRepository implements StudentRepository {
  const FakeStudentRepository(ShiTiApiClient apiClient);

  static final List<StudentWorkspaceRecord> _records =
      List<StudentWorkspaceRecord>.of(sampleStudentRecords);

  @override
  Future<List<StudentWorkspaceRecord>> listStudents({
    String? query,
    String? classId,
    String? lessonId,
  }) async {
    final keyword = query?.trim().toLowerCase() ?? '';
    final normalizedClassId = classId?.trim();
    final normalizedLessonId = lessonId?.trim();
    return _records.where((student) {
      final matchesKeyword = keyword.isEmpty ||
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
      return !student.isArchived &&
          matchesKeyword &&
          matchesClass &&
          matchesLesson;
    }).toList(growable: false);
  }

  @override
  Future<StudentWorkspaceRecord?> getStudent(String studentId) async {
    try {
      return _records.firstWhere((student) => student.id == studentId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<StudentWorkspaceRecord> createStudent({
    required String name,
    required String gradeLabel,
    required String subjectLabel,
    required String textbookLabel,
    String? classId,
    String? className,
    String? lessonId,
    String? documentId,
    String? documentName,
  }) async {
    final created = StudentWorkspaceRecord(
      id: 'student-${_records.length + 1}',
      name: name,
      classId: classId ?? '',
      className: className ?? '',
      lessonId: lessonId ?? '',
      documentId: documentId ?? '',
      documentName: documentName ?? '',
      gradeLabel: gradeLabel,
      subjectLabel: subjectLabel,
      textbookLabel: textbookLabel,
      trendLabel: '新建档案',
      habitTag: '待观察',
      habitInsight: '等待补充学习习惯、课堂反馈与课后跟进情况。',
      followUpLevel: '常规关注',
      summary: '新建学生档案，等待补充成绩、错题与课堂反馈。',
      scoreLabel: '暂无成绩',
      historyTrendLabel: '待记录',
      wrongCountLabel: '0 道',
      wrongCount: 0,
      scoreRecords: const [],
      feedbackRecords: const [],
      wrongQuestionRecords: const [],
      highlights: const ['已创建学生档案，可继续补充班级、课堂与资料承接。'],
      nextStep: '补充最近一次测评、课堂反馈和错题跟进。',
      archivedAt: null,
    );
    _records.insert(0, created);
    return created;
  }

  @override
  Future<StudentWorkspaceRecord> updateStudent({
    required String studentId,
    required String name,
    required String gradeLabel,
    required String subjectLabel,
    required String textbookLabel,
    String? classId,
    String? className,
    String? lessonId,
    String? documentId,
    String? documentName,
  }) async {
    final index = _records.indexWhere((student) => student.id == studentId);
    if (index < 0) {
      throw StateError('Student not found');
    }
    final current = _records[index];
    final updated = StudentWorkspaceRecord(
      id: current.id,
      name: name,
      classId: classId ?? current.classId,
      className: className ?? current.className,
      lessonId: lessonId ?? current.lessonId,
      documentId: documentId ?? current.documentId,
      documentName: documentName ?? current.documentName,
      gradeLabel: gradeLabel,
      subjectLabel: subjectLabel,
      textbookLabel: textbookLabel,
      trendLabel: current.trendLabel,
      habitTag: current.habitTag,
      habitInsight: current.habitInsight,
      followUpLevel: current.followUpLevel,
      summary: current.summary,
      scoreLabel: current.scoreLabel,
      historyTrendLabel: current.historyTrendLabel,
      wrongCountLabel: current.wrongCountLabel,
      wrongCount: current.wrongCount,
      scoreRecords: current.scoreRecords,
      feedbackRecords: current.feedbackRecords,
      wrongQuestionRecords: current.wrongQuestionRecords,
      highlights: current.highlights,
      nextStep: current.nextStep,
      archivedAt: current.archivedAt,
    );
    _records[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteStudent(String studentId) async {
    _records.removeWhere((student) => student.id == studentId);
  }

  @override
  Future<StudentWorkspaceRecord> setStudentArchived(
    String studentId, {
    required bool archived,
  }) async {
    final index = _records.indexWhere((student) => student.id == studentId);
    if (index < 0) {
      throw StateError('Student not found');
    }
    final current = _records[index];
    final updated = StudentWorkspaceRecord(
      id: current.id,
      name: current.name,
      classId: current.classId,
      className: current.className,
      lessonId: current.lessonId,
      documentId: current.documentId,
      documentName: current.documentName,
      gradeLabel: current.gradeLabel,
      subjectLabel: current.subjectLabel,
      textbookLabel: current.textbookLabel,
      trendLabel: current.trendLabel,
      habitTag: current.habitTag,
      habitInsight: current.habitInsight,
      followUpLevel: current.followUpLevel,
      summary: current.summary,
      scoreLabel: current.scoreLabel,
      historyTrendLabel: current.historyTrendLabel,
      wrongCountLabel: current.wrongCountLabel,
      wrongCount: current.wrongCount,
      scoreRecords: current.scoreRecords,
      feedbackRecords: current.feedbackRecords,
      wrongQuestionRecords: current.wrongQuestionRecords,
      highlights: current.highlights,
      nextStep: current.nextStep,
      archivedAt: archived ? (current.archivedAt ?? DateTime.now()) : null,
    );
    _records[index] = updated;
    return updated;
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
        .map((item) =>
            StudentWorkspaceRecord.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<StudentWorkspaceRecord?> getStudent(String studentId) async {
    final response =
        await _client.getObject('/students/$studentId', objectKey: 'student');
    if (response.isEmpty) {
      return null;
    }
    return StudentWorkspaceRecord.fromJson(response);
  }

  @override
  Future<StudentWorkspaceRecord> createStudent({
    required String name,
    required String gradeLabel,
    required String subjectLabel,
    required String textbookLabel,
    String? classId,
    String? className,
    String? lessonId,
    String? documentId,
    String? documentName,
  }) async {
    final response = await _client.postObject(
      '/students',
      body: {
        'name': name,
        'gradeLabel': gradeLabel,
        'subjectLabel': subjectLabel,
        'textbookLabel': textbookLabel,
        'classId': classId,
        if (className != null && className.trim().isNotEmpty)
          'className': className.trim(),
        'lessonId': lessonId,
        'documentId': documentId,
        'documentName': documentName,
      },
    );
    return StudentWorkspaceRecord.fromJson(
        response['student'] as Map<String, dynamic>);
  }

  @override
  Future<StudentWorkspaceRecord> updateStudent({
    required String studentId,
    required String name,
    required String gradeLabel,
    required String subjectLabel,
    required String textbookLabel,
    String? classId,
    String? className,
    String? lessonId,
    String? documentId,
    String? documentName,
  }) async {
    final response = await _client.patchObject(
      '/students/$studentId',
      body: {
        'name': name,
        'gradeLabel': gradeLabel,
        'subjectLabel': subjectLabel,
        'textbookLabel': textbookLabel,
        'classId': classId,
        'className': className,
        'lessonId': lessonId,
        'documentId': documentId,
        'documentName': documentName,
      },
    );
    return StudentWorkspaceRecord.fromJson(
        response['student'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteStudent(String studentId) async {
    await _client.deleteObject('/students/$studentId');
  }

  @override
  Future<StudentWorkspaceRecord> setStudentArchived(
    String studentId, {
    required bool archived,
  }) async {
    final response = await _client.patchObject(
      '/students/$studentId',
      body: {'archived': archived},
    );
    return StudentWorkspaceRecord.fromJson(
      response['student'] as Map<String, dynamic>,
    );
  }
}
