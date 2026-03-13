import '../api/shiti_api_client.dart';
import '../models/library_filter_state.dart';
import '../models/question_summary.dart';
import '../network/http_json_client.dart';

abstract class QuestionRepository {
  Future<List<QuestionSummary>> listQuestions({
    LibraryFilterState filters = const LibraryFilterState(),
  });

  Future<QuestionSummary?> getQuestion(String questionId);

  Future<List<QuestionSummary>> listBasketQuestions();
}

class FakeQuestionRepository implements QuestionRepository {
  const FakeQuestionRepository(this._apiClient);

  final ShiTiApiClient _apiClient;

  @override
  Future<List<QuestionSummary>> listQuestions({
    LibraryFilterState filters = const LibraryFilterState(),
  }) {
    return _apiClient.listQuestions(filters: filters);
  }

  @override
  Future<QuestionSummary?> getQuestion(String questionId) async {
    final questions = await listQuestions();
    for (final question in questions) {
      if (question.id == questionId) {
        return question;
      }
    }
    return null;
  }

  @override
  Future<List<QuestionSummary>> listBasketQuestions() {
    return _apiClient.listBasketQuestions();
  }
}

class RemoteQuestionRepository implements QuestionRepository {
  const RemoteQuestionRepository(this._client);

  final HttpJsonClient _client;

  @override
  Future<List<QuestionSummary>> listQuestions({
    LibraryFilterState filters = const LibraryFilterState(),
  }) async {
    final items = await _client.getList(
      '/questions',
      query: <String, String>{
        if (filters.query.trim().isNotEmpty) 'q': filters.query.trim(),
        'include': 'tags,summary',
      },
      listKey: 'questions',
    );
    final questions = items
        .whereType<Map<String, dynamic>>()
        .map(_mapQuestionSummary)
        .toList();
    return _applyClientFilters(questions, filters);
  }

  @override
  Future<QuestionSummary?> getQuestion(String questionId) async {
    final object = await _client.getObject('/questions/$questionId');
    if (object.isEmpty) {
      return null;
    }
    final question = object['question'];
    if (question is! Map<String, dynamic>) {
      return null;
    }

    final content = object['content'];
    final tags = object['tags'];
    final stages = object['stages'];
    final grades = object['grades'];
    final textbooks = object['textbooks'];
    final chapters = object['chapters'];

    return _mapQuestionSummary(<String, dynamic>{
      ...question,
      'tags': tags,
      'summary': <String, dynamic>{
        'stemPreview': _extractBlockText(
          content is Map<String, dynamic> ? content['stemBlocks'] : null,
        ),
        'stages': stages,
        'grades': grades,
        'textbooks': textbooks,
        'chapters': chapters,
      },
    });
  }

  @override
  Future<List<QuestionSummary>> listBasketQuestions() {
    return listQuestions();
  }

  List<QuestionSummary> _applyClientFilters(
    List<QuestionSummary> questions,
    LibraryFilterState filters,
  ) {
    return questions.where((question) {
      final matchesSubject = filters.subject == '全部学科' ||
          question.subject.trim() == filters.subject.trim();
      final matchesStage = filters.stage == '全部学段' ||
          question.stage.trim() == filters.stage.trim();
      final matchesTextbook = filters.textbook == '全部教材' ||
          question.textbook.trim() == filters.textbook.trim();
      final trimmedQuery = filters.query.trim().toLowerCase();
      final matchesQuery = trimmedQuery.isEmpty ||
          question.title.toLowerCase().contains(trimmedQuery) ||
          question.chapter.toLowerCase().contains(trimmedQuery) ||
          question.stemPreview.toLowerCase().contains(trimmedQuery) ||
          question.tags.any(
            (tag) => tag.toLowerCase().contains(trimmedQuery),
          );
      return matchesSubject &&
          matchesStage &&
          matchesTextbook &&
          matchesQuery;
    }).toList();
  }

  QuestionSummary _mapQuestionSummary(Map<String, dynamic> json) {
    final tagsValue = json['tags'];
    final summary = json['summary'];
    final summaryMap = summary is Map<String, dynamic>
        ? summary
        : const <String, dynamic>{};
    final tagLabels = <String>[];
    if (tagsValue is List) {
      for (final tag in tagsValue) {
        if (tag is Map<String, dynamic>) {
          final label = tag['label'] ?? tag['name'];
          if (label is String) {
            tagLabels.add(label);
          }
        } else if (tag is String) {
          tagLabels.add(tag);
        }
      }
    }

    final stageLabels = _extractNamedLabels(summaryMap['stages']);
    final gradeLabels = _extractNamedLabels(summaryMap['grades']);
    final textbookLabels = _extractNamedLabels(summaryMap['textbooks']);
    final chapterLabels = _extractNamedLabels(summaryMap['chapters']);

    return QuestionSummary(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? json['id'] ?? '未命名题目').toString(),
      subject: (json['subjectName'] ?? json['subject'] ?? '未分类').toString(),
      stage: stageLabels.isNotEmpty
          ? stageLabels.first
          : (json['stageName'] ?? json['stage'] ?? '未标注').toString(),
      grade: gradeLabels.isNotEmpty
          ? gradeLabels.first
          : (json['gradeName'] ?? json['grade'] ?? '未标注').toString(),
      textbook: textbookLabels.isNotEmpty
          ? textbookLabels.first
          : (json['textbookName'] ?? json['textbook'] ?? '未标注').toString(),
      chapter: chapterLabels.isNotEmpty
          ? chapterLabels.first
          : (json['chapterName'] ?? json['chapter'] ?? '未标注').toString(),
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 3,
      tags: tagLabels,
      stemPreview: (summaryMap['stemPreview'] ??
              json['stemPreview'] ??
              json['contentPreview'] ??
              '待加载题干')
          .toString(),
    );
  }

  List<String> _extractNamedLabels(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .whereType<Map<String, dynamic>>()
        .map((item) => (item['name'] ?? '').toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _extractBlockText(dynamic value) {
    if (value is List) {
      return value
          .map((item) => _extractBlockText(item))
          .where((item) => item.isNotEmpty)
          .join(' ')
          .trim();
    }
    if (value is Map<String, dynamic>) {
      final text = value['text'];
      if (text is String && text.trim().isNotEmpty) {
        return text.trim();
      }
      return value.values
          .map((item) => _extractBlockText(item))
          .where((item) => item.isNotEmpty)
          .join(' ')
          .trim();
    }
    if (value is String) {
      return value.trim();
    }
    return '';
  }
}
