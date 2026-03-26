import '../api/shiti_api_client.dart';
import '../models/question_detail.dart';
import '../models/library_filter_state.dart';
import '../models/question_summary.dart';
import '../network/http_json_client.dart';

abstract class QuestionRepository {
  Future<List<QuestionSummary>> listQuestions({
    LibraryFilterState filters = const LibraryFilterState(),
  });

  Future<QuestionSummary?> getQuestion(String questionId);

  Future<QuestionDetail?> getQuestionDetail(String questionId);

  Future<QuestionDetail> createQuestion({
    required String stemText,
    required String analysisText,
    required String solutionText,
    required String commentaryText,
    required String type,
    required int difficulty,
    required String defaultScore,
    String? subjectId,
  });

  Future<QuestionDetail> updateQuestion({
    required String questionId,
    required String stemText,
    required String analysisText,
    required String solutionText,
    required String commentaryText,
    required String type,
    required int difficulty,
    required String defaultScore,
    String? subjectId,
  });

  Future<void> deleteQuestion(String questionId);

  Future<List<QuestionSummary>> listBasketQuestions();

  Future<Set<String>> listBasketQuestionIds();

  Future<void> addQuestionToBasket(QuestionSummary question);

  Future<void> removeQuestionFromBasket(String questionId);

  Future<void> clearBasket();
}

class FakeQuestionRepository implements QuestionRepository {
  const FakeQuestionRepository(this._apiClient);

  final ShiTiApiClient _apiClient;
  static final Map<String, QuestionDetail> _overrides =
      <String, QuestionDetail>{};
  static final Set<String> _deletedIds = <String>{};

  @override
  Future<List<QuestionSummary>> listQuestions({
    LibraryFilterState filters = const LibraryFilterState(),
  }) {
    return _listQuestions(filters: filters);
  }

  @override
  Future<QuestionSummary?> getQuestion(String questionId) async {
    final questions = await _listQuestions();
    for (final question in questions) {
      if (question.id == questionId) {
        return question;
      }
    }
    return null;
  }

  @override
  Future<QuestionDetail?> getQuestionDetail(String questionId) {
    return _getQuestionDetail(questionId);
  }

  @override
  Future<QuestionDetail> createQuestion({
    required String stemText,
    required String analysisText,
    required String solutionText,
    required String commentaryText,
    required String type,
    required int difficulty,
    required String defaultScore,
    String? subjectId,
  }) async {
    final detail = QuestionDetail(
      id: 'q-${DateTime.now().millisecondsSinceEpoch}',
      title: _buildQuestionTitle(stemText),
      type: type,
      subject: '数学',
      stage: '未标注',
      grade: '未标注',
      textbook: '未标注',
      chapter: '未标注',
      difficulty: difficulty,
      defaultScore: defaultScore,
      tags: const <String>[],
      stemBlocks: _textBlocks(stemText),
      analysisBlocks: _textBlocks(analysisText),
      solutionBlocks: _textBlocks(solutionText),
      referenceAnswerBlocks: const <Map<String, dynamic>>[],
      scoringPointBlocks: const <Map<String, dynamic>>[],
      commentaryBlocks: _textBlocks(commentaryText),
      sourceBlocks: const <Map<String, dynamic>>[],
      stemText: stemText.trim(),
      analysisText: analysisText.trim(),
      solutionText: solutionText.trim(),
      referenceAnswerText: '',
      scoringPointsText: '',
      commentaryText: commentaryText.trim(),
      sourceText: '',
    );
    _deletedIds.remove(detail.id);
    _overrides[detail.id] = detail;
    return detail;
  }

  @override
  Future<QuestionDetail> updateQuestion({
    required String questionId,
    required String stemText,
    required String analysisText,
    required String solutionText,
    required String commentaryText,
    required String type,
    required int difficulty,
    required String defaultScore,
    String? subjectId,
  }) async {
    final current = await _getQuestionDetail(questionId);
    if (current == null) {
      throw StateError('Question not found');
    }
    final updated = QuestionDetail(
      id: current.id,
      title: _buildQuestionTitle(stemText),
      type: type,
      subject: current.subject,
      stage: current.stage,
      grade: current.grade,
      textbook: current.textbook,
      chapter: current.chapter,
      difficulty: difficulty,
      defaultScore: defaultScore,
      tags: current.tags,
      stemBlocks: _textBlocks(stemText),
      analysisBlocks: _textBlocks(analysisText),
      solutionBlocks: _textBlocks(solutionText),
      referenceAnswerBlocks: current.referenceAnswerBlocks,
      scoringPointBlocks: current.scoringPointBlocks,
      commentaryBlocks: _textBlocks(commentaryText),
      sourceBlocks: current.sourceBlocks,
      stemText: stemText.trim(),
      analysisText: analysisText.trim(),
      solutionText: solutionText.trim(),
      referenceAnswerText: current.referenceAnswerText,
      scoringPointsText: current.scoringPointsText,
      commentaryText: commentaryText.trim(),
      sourceText: current.sourceText,
    );
    _overrides[questionId] = updated;
    return updated;
  }

  @override
  Future<void> deleteQuestion(String questionId) async {
    _overrides.remove(questionId);
    _deletedIds.add(questionId);
  }

  @override
  Future<List<QuestionSummary>> listBasketQuestions() {
    return _listBasketQuestions();
  }

  @override
  Future<Set<String>> listBasketQuestionIds() async {
    final questions = await _listBasketQuestions();
    return questions.map((question) => question.id).toSet();
  }

  @override
  Future<void> addQuestionToBasket(QuestionSummary question) {
    return _apiClient.addQuestionToBasket(question.id);
  }

  @override
  Future<void> removeQuestionFromBasket(String questionId) {
    return _apiClient.removeQuestionFromBasket(questionId);
  }

  @override
  Future<void> clearBasket() {
    return _apiClient.clearBasket();
  }

  Future<List<QuestionSummary>> _listQuestions({
    LibraryFilterState filters = const LibraryFilterState(),
  }) async {
    final base = await _apiClient.listQuestions(
      filters: const LibraryFilterState(),
    );
    final merged = <String, QuestionSummary>{
      for (final question in base)
        if (!_deletedIds.contains(question.id)) question.id: question,
    };
    for (final entry in _overrides.entries) {
      if (_deletedIds.contains(entry.key)) {
        continue;
      }
      merged[entry.key] = _summaryFromDetail(entry.value);
    }
    return _applyQuestionClientFilters(
      merged.values.toList(growable: false),
      filters,
    );
  }

  Future<QuestionDetail?> _getQuestionDetail(String questionId) async {
    if (_deletedIds.contains(questionId)) {
      return null;
    }
    final override = _overrides[questionId];
    if (override != null) {
      return override;
    }
    return _apiClient.getQuestionDetail(questionId);
  }

  Future<List<QuestionSummary>> _listBasketQuestions() async {
    final questions = await _listQuestions();
    final basketIds = await _apiClient.listBasketQuestions().then(
          (items) => items.map((item) => item.id).toSet(),
        );
    return questions
        .where((question) => basketIds.contains(question.id))
        .toList();
  }

  QuestionSummary _summaryFromDetail(QuestionDetail detail) {
    return QuestionSummary(
      id: detail.id,
      title: detail.title,
      type: detail.type,
      subject: detail.subject,
      stage: detail.stage,
      grade: detail.grade,
      textbook: detail.textbook,
      chapter: detail.chapter,
      difficulty: detail.difficulty,
      defaultScore: detail.defaultScore,
      tags: detail.tags,
      stemPreview: detail.stemText,
      previewBlocks: detail.stemBlocks,
    );
  }
}

class RemoteQuestionRepository implements QuestionRepository {
  RemoteQuestionRepository(this._client);

  final HttpJsonClient _client;
  final Set<String> _basketQuestionIds = <String>{};
  bool _basketInitialized = false;

  @override
  Future<List<QuestionSummary>> listQuestions({
    LibraryFilterState filters = const LibraryFilterState(),
  }) async {
    final items = await _client.getList(
      '/questions',
      query: <String, String>{
        if (filters.query.trim().isNotEmpty) 'q': filters.query.trim(),
        if ((filters.subjectId ?? '').trim().isNotEmpty)
          'subjectId': filters.subjectId!.trim(),
        if ((filters.stageId ?? '').trim().isNotEmpty)
          'stageId': filters.stageId!.trim(),
        if ((filters.textbookId ?? '').trim().isNotEmpty)
          'textbookId': filters.textbookId!.trim(),
        'include': 'tags,summary',
      },
      listKey: 'questions',
    );
    final questions = items
        .whereType<Map<String, dynamic>>()
        .map(_mapQuestionSummary)
        .toList();
    return _applyQuestionClientFilters(questions, filters);
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
  Future<QuestionDetail?> getQuestionDetail(String questionId) async {
    final object = await _client.getObject('/questions/$questionId');
    if (object.isEmpty) {
      return null;
    }
    final question = object['question'];
    if (question is! Map<String, dynamic>) {
      return null;
    }

    final content = object['content'];
    final explanation = object['explanation'];
    final solutionAnswer = object['solutionAnswer'];
    final source = object['source'];
    final tags = object['tags'];
    final stages = object['stages'];
    final grades = object['grades'];
    final textbooks = object['textbooks'];
    final chapters = object['chapters'];

    final summary = _mapQuestionSummary(<String, dynamic>{
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

    final explanationMap = explanation is Map<String, dynamic>
        ? explanation
        : const <String, dynamic>{};
    final solutionAnswerMap = solutionAnswer is Map<String, dynamic>
        ? solutionAnswer
        : const <String, dynamic>{};
    final sourceMap =
        source is Map<String, dynamic> ? source : const <String, dynamic>{};

    final stemBlocks = _normalizeBlocks(
      _firstNonNull(
        content is Map<String, dynamic> ? content['stemBlocks'] : null,
        content is Map<String, dynamic> ? content['stem'] : null,
        content is Map<String, dynamic> ? content['contentBlocks'] : null,
        content is Map<String, dynamic> ? content['content'] : null,
        content is Map<String, dynamic> ? content['blocks'] : null,
        content is Map<String, dynamic> ? content['stemLatex'] : null,
        content is Map<String, dynamic> ? content['stemText'] : null,
      ),
    );
    final analysisBlocks = _normalizeBlocks(
      _firstNonNull(
        explanationMap['overviewBlocks'],
        explanationMap['analysisBlocks'],
        explanationMap['overview'],
        explanationMap['analysis'],
        explanationMap['overviewLatex'],
        explanationMap['analysisLatex'],
        explanationMap['overviewText'],
      ),
    );
    final solutionBlocks = _normalizeBlocks(
      _firstNonNull(
        _firstNonNull(
          explanationMap['stepsBlocks'],
          explanationMap['solutionBlocks'],
          explanationMap['steps'],
          explanationMap['solution'],
          explanationMap['stepsLatex'],
          explanationMap['solutionLatex'],
          explanationMap['stepsText'],
        ),
        _firstNonNull(
          solutionAnswerMap['referenceAnswerBlocks'],
          solutionAnswerMap['referenceAnswer'],
          solutionAnswerMap['finalAnswerLatex'],
          solutionAnswerMap['referenceAnswerText'],
        ),
      ),
    );
    final referenceAnswerBlocks = _normalizeBlocks(
      _firstNonNull(
        solutionAnswerMap['referenceAnswerBlocks'],
        solutionAnswerMap['referenceAnswer'],
        solutionAnswerMap['finalAnswerLatex'],
        solutionAnswerMap['referenceAnswerText'],
      ),
    );
    final scoringPointBlocks = _normalizeScoringPointBlocks(
      solutionAnswerMap['scoringPoints'],
    );
    final commentaryBlocks = _normalizeBlocks(
      _firstNonNull(
        explanationMap['commentaryBlocks'],
        explanationMap['commentary'],
        explanationMap['commentaryLatex'],
        explanationMap['commentaryText'],
      ),
    );
    final sourceBlocks = _normalizeBlocks(
      _firstNonNull(
        sourceMap['blocks'],
        sourceMap['sourceBlocks'],
        sourceMap['contentBlocks'],
        sourceMap['content'],
        _formatSourceText(sourceMap),
      ),
    );

    return QuestionDetail(
      id: summary.id,
      title: summary.title,
      type: summary.type,
      subject: summary.subject,
      stage: summary.stage,
      grade: summary.grade,
      textbook: summary.textbook,
      chapter: summary.chapter,
      difficulty: summary.difficulty,
      defaultScore: summary.defaultScore,
      tags: summary.tags,
      stemBlocks: stemBlocks,
      analysisBlocks: analysisBlocks,
      solutionBlocks: solutionBlocks,
      referenceAnswerBlocks: referenceAnswerBlocks,
      scoringPointBlocks: scoringPointBlocks,
      commentaryBlocks: commentaryBlocks,
      sourceBlocks: sourceBlocks,
      stemText: _extractBlockText(stemBlocks),
      analysisText: _extractBlockText(analysisBlocks),
      solutionText: _extractBlockText(
        solutionBlocks,
      ),
      referenceAnswerText: _extractBlockText(
        referenceAnswerBlocks,
      ),
      scoringPointsText: _extractBlockText(scoringPointBlocks),
      commentaryText: _extractBlockText(commentaryBlocks),
      sourceText: _formatSourceText(sourceMap),
    );
  }

  @override
  Future<QuestionDetail> createQuestion({
    required String stemText,
    required String analysisText,
    required String solutionText,
    required String commentaryText,
    required String type,
    required int difficulty,
    required String defaultScore,
    String? subjectId,
  }) async {
    final created = await _client.postObject(
      '/questions',
      body: {
        if (subjectId != null && subjectId.trim().isNotEmpty)
          'subjectId': subjectId.trim(),
      },
    );
    final question = created['question'];
    if (question is! Map<String, dynamic>) {
      throw const HttpJsonException(statusCode: 500, message: '创建题目失败');
    }
    final questionId = (question['id'] ?? '').toString();
    await _persistQuestionDraft(
      questionId: questionId,
      stemText: stemText,
      analysisText: analysisText,
      solutionText: solutionText,
      commentaryText: commentaryText,
      type: type,
      difficulty: difficulty,
      defaultScore: defaultScore,
      subjectId: subjectId,
    );
    final detail = await getQuestionDetail(questionId);
    if (detail == null) {
      throw const HttpJsonException(statusCode: 500, message: '题目创建后未能加载详情');
    }
    return detail;
  }

  @override
  Future<QuestionDetail> updateQuestion({
    required String questionId,
    required String stemText,
    required String analysisText,
    required String solutionText,
    required String commentaryText,
    required String type,
    required int difficulty,
    required String defaultScore,
    String? subjectId,
  }) async {
    await _persistQuestionDraft(
      questionId: questionId,
      stemText: stemText,
      analysisText: analysisText,
      solutionText: solutionText,
      commentaryText: commentaryText,
      type: type,
      difficulty: difficulty,
      defaultScore: defaultScore,
      subjectId: subjectId,
    );
    final detail = await getQuestionDetail(questionId);
    if (detail == null) {
      throw const HttpJsonException(statusCode: 404, message: '未找到对应题目');
    }
    return detail;
  }

  @override
  Future<void> deleteQuestion(String questionId) async {
    await _client.deleteObject('/questions/$questionId');
  }

  @override
  Future<List<QuestionSummary>> listBasketQuestions() {
    return _listBasketQuestions();
  }

  @override
  Future<Set<String>> listBasketQuestionIds() async {
    await _ensureBasketInitialized();
    return Set<String>.from(_basketQuestionIds);
  }

  @override
  Future<void> addQuestionToBasket(QuestionSummary question) async {
    _basketQuestionIds.add(question.id);
  }

  @override
  Future<void> removeQuestionFromBasket(String questionId) async {
    _basketQuestionIds.remove(questionId);
  }

  @override
  Future<void> clearBasket() async {
    _basketQuestionIds.clear();
    _basketInitialized = true;
  }

  Future<void> _ensureBasketInitialized() async {
    if (_basketInitialized) {
      return;
    }
    final questions = await listQuestions();
    _basketQuestionIds
      ..clear()
      ..addAll(questions.take(2).map((question) => question.id));
    _basketInitialized = true;
  }

  Future<List<QuestionSummary>> _listBasketQuestions() async {
    final questions = await listQuestions();
    await _ensureBasketInitialized();
    return questions
        .where((question) => _basketQuestionIds.contains(question.id))
        .toList();
  }

  QuestionSummary _mapQuestionSummary(Map<String, dynamic> json) {
    final tagsValue = json['tags'];
    final summary = json['summary'];
    final summaryMap =
        summary is Map<String, dynamic> ? summary : const <String, dynamic>{};
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
      title: (json['title'] ??
              summaryMap['stemPreview'] ??
              json['stemPreview'] ??
              json['id'] ??
              '未命名题目')
          .toString(),
      type: (json['type'] ?? 'solution').toString(),
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
      defaultScore: (json['defaultScore'] ?? '5.00').toString(),
      tags: tagLabels,
      stemPreview: (summaryMap['stemPreview'] ??
              json['stemPreview'] ??
              json['contentPreview'] ??
              '待加载题干')
          .toString(),
      previewBlocks: _normalizeBlocks(
        summaryMap['previewBlocks'] ??
            summaryMap['preview'] ??
            summaryMap['stemBlocks'] ??
            summaryMap['stem'] ??
            json['previewBlocks'] ??
            json['preview'] ??
            json['stemBlocks'] ??
            json['stem'] ??
            json['contentBlocks'] ??
            json['content'] ??
            summaryMap['stemPreview'] ??
            json['stemPreview'] ??
            json['contentPreview'],
      ),
    );
  }

  Future<void> _persistQuestionDraft({
    required String questionId,
    required String stemText,
    required String analysisText,
    required String solutionText,
    required String commentaryText,
    required String type,
    required int difficulty,
    required String defaultScore,
    String? subjectId,
  }) async {
    await _client.patchObject(
      '/questions/$questionId',
      body: {
        'type': type,
        'difficulty': difficulty,
        'defaultScore': defaultScore,
        if (subjectId != null && subjectId.trim().isNotEmpty)
          'subjectId': subjectId.trim(),
      },
    );
    await _client.putObject(
      '/questions/$questionId/content',
      body: {'stemBlocks': _textBlocks(stemText)},
    );
    await _client.putObject(
      '/questions/$questionId/explanation',
      body: {
        if (analysisText.trim().isNotEmpty)
          'overviewBlocks': _textBlocks(analysisText),
        'stepsBlocks': _textBlocks(solutionText),
        if (commentaryText.trim().isNotEmpty)
          'commentaryBlocks': _textBlocks(commentaryText),
      },
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
    if (value is Map<String, dynamic>) {
      final nestedBlocks =
          value['blocks'] ?? value['children'] ?? value['items'];
      if (nestedBlocks != null) {
        final nestedText = _extractBlockText(nestedBlocks);
        if (nestedText.isNotEmpty) {
          return nestedText;
        }
      }
    }
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

  List<Map<String, dynamic>> _normalizeBlocks(dynamic value) {
    if (value is List) {
      final blocks = <Map<String, dynamic>>[];
      for (final item in value) {
        blocks.addAll(_normalizeBlocks(item));
      }
      return blocks;
    }
    if (value is Map) {
      final normalizedMap = value.map(
        (key, itemValue) => MapEntry(key.toString(), itemValue),
      );
      final block = _normalizeBlockMap(normalizedMap);
      if (block != null) {
        return <Map<String, dynamic>>[block];
      }

      final nestedBlocks = normalizedMap['blocks'] ??
          normalizedMap['content'] ??
          normalizedMap['children'] ??
          normalizedMap['items'] ??
          normalizedMap['columns'] ??
          normalizedMap['column'] ??
          normalizedMap['checklist'] ??
          normalizedMap['tasks'] ??
          normalizedMap['link'] ??
          normalizedMap['step'] ??
          normalizedMap['steps'] ??
          normalizedMap['list'] ??
          normalizedMap['quote'] ??
          normalizedMap['callout'] ??
          normalizedMap['note'] ??
          normalizedMap['code'] ??
          normalizedMap['snippet'] ??
          normalizedMap['embed'] ??
          normalizedMap['video'] ??
          normalizedMap['audio'] ??
          normalizedMap['heading'] ??
          normalizedMap['title'] ??
          normalizedMap['divider'] ??
          normalizedMap['separator'] ??
          normalizedMap['image'] ??
          normalizedMap['media'] ??
          normalizedMap['figure'] ??
          normalizedMap['asset'] ??
          normalizedMap['table'];
      if (nestedBlocks != null) {
        return _normalizeBlocks(nestedBlocks);
      }
    }
    if (value is String && value.trim().isNotEmpty) {
      return <Map<String, dynamic>>[
        <String, dynamic>{'type': 'text', 'text': value.trim()},
      ];
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic>? _normalizeBlockMap(Map<String, dynamic> block) {
    final hasType = (block['type'] ?? '').toString().trim().isNotEmpty;
    final hasText = (block['text'] is String &&
            (block['text'] as String).trim().isNotEmpty) ||
        (block['label'] is String &&
            (block['label'] as String).trim().isNotEmpty) ||
        (block['caption'] is String &&
            (block['caption'] as String).trim().isNotEmpty) ||
        (block['alt'] is String &&
            (block['alt'] as String).trim().isNotEmpty) ||
        (block['href'] is String &&
            (block['href'] as String).trim().isNotEmpty) ||
        (block['link'] is String &&
            (block['link'] as String).trim().isNotEmpty) ||
        block['assetId'] != null ||
        block['src'] != null ||
        block['url'] != null ||
        block['rows'] is List ||
        block['headers'] is List ||
        block['bodyRows'] is List ||
        block['ordered'] is bool ||
        block['list'] is List ||
        block['bullets'] is List ||
        block['timeline'] is List ||
        block['events'] is List ||
        block['entries'] is List ||
        block['date'] != null ||
        block['time'] != null ||
        block['stats'] is List ||
        block['metrics'] is List ||
        block['value'] != null ||
        block['tabs'] is List ||
        block['sections'] is List ||
        block['tab'] != null ||
        block['comparison'] is List ||
        block['before'] != null ||
        block['after'] != null ||
        block['matrix'] is List ||
        block['grid'] is List ||
        block['flow'] is List ||
        block['process'] is List ||
        block['rubric'] is List ||
        block['criteria'] is List ||
        block['decision'] is List ||
        block['branches'] is List ||
        block['legend'] is List ||
        block['key'] is List ||
        block['pairs'] is List ||
        block['attributes'] is List ||
        block['schema'] is List ||
        block['map'] is List ||
        block['milestones'] is List ||
        block['checkpoints'] is List ||
        block['badges'] is List ||
        block['chips'] is List ||
        block['references'] is List ||
        block['footnotes'] is List ||
        block['chart'] is List ||
        block['series'] is List ||
        block['points'] is List ||
        block['highlights'] is List ||
        block['annotations'] is List ||
        block['outline'] is List ||
        block['syllabus'] is List ||
        block['warnings'] is List ||
        block['alerts'] is List ||
        block['pitfalls'] is List ||
        block['misconceptions'] is List ||
        block['glossary'] is List ||
        block['terms'] is List ||
        block['examples'] is List ||
        block['samples'] is List ||
        block['tips'] is List ||
        block['hints'] is List ||
        block['objectives'] is List ||
        block['goals'] is List ||
        block['prerequisites'] is List ||
        block['requirements'] is List ||
        block['materials'] is List ||
        block['resources'] is List ||
        block['constraints'] is List ||
        block['rules'] is List ||
        block['notes'] is List ||
        block['remarks'] is List ||
        block['takeaways'] is List ||
        block['insights'] is List ||
        block['activities'] is List ||
        block['drills'] is List ||
        block['strategies'] is List ||
        block['approaches'] is List ||
        block['checks'] is List ||
        block['validations'] is List ||
        block['heuristics'] is List ||
        block['rulesOfThumb'] is List ||
        block['signals'] is List ||
        block['indicators'] is List ||
        block['evidence'] is List ||
        block['proofs'] is List ||
        block['counterexamples'] is List ||
        block['nonExamples'] is List ||
        block['patterns'] is List ||
        block['motifs'] is List ||
        block['variations'] is List ||
        block['scenarios'] is List ||
        block['prompts'] is List ||
        block['cues'] is List ||
        block['outcomes'] is List ||
        block['results'] is List ||
        block['principles'] is List ||
        block['guidelines'] is List ||
        block['phases'] is List ||
        block['segments'] is List ||
        block['anchors'] is List ||
        block['checkpoints'] is List ||
        block['priorities'] is List ||
        block['focuses'] is List ||
        block['roles'] is List ||
        block['responsibilities'] is List ||
        block['agenda'] is List ||
        block['schedule'] is List ||
        block['corrections'] is List ||
        block['missteps'] is List ||
        block['facets'] is List ||
        block['dimensions'] is List ||
        block['dialogue'] is List ||
        block['discussion'] is List ||
        block['observations'] is List ||
        block['findings'] is List ||
        block['actions'] is List ||
        block['moves'] is List ||
        block['transitions'] is List ||
        block['handoffs'] is List ||
        block['accordion'] is List ||
        block['details'] is List ||
        block['summary'] != null ||
        block['faq'] is List ||
        block['qa'] is List ||
        block['question'] != null ||
        block['answer'] != null ||
        block['quote'] != null ||
        block['callout'] != null ||
        block['note'] != null ||
        block['code'] != null ||
        block['snippet'] != null ||
        block['language'] != null ||
        block['step'] != null ||
        block['steps'] != null ||
        block['index'] is num ||
        block['columns'] is List ||
        block['column'] is List ||
        block['checklist'] is List ||
        block['tasks'] is List ||
        block['checked'] is bool ||
        block['embed'] != null ||
        block['video'] != null ||
        block['audio'] != null ||
        block['mediaUrl'] != null ||
        block['heading'] != null ||
        block['title'] != null ||
        block['divider'] == true ||
        block['separator'] == true ||
        block['level'] is num;
    if (!hasType && !hasText) {
      return null;
    }

    final normalized = <String, dynamic>{...block};
    normalized['type'] =
        hasType ? block['type'].toString() : _inferBlockType(block);

    if (normalized['assetId'] == null) {
      normalized['assetId'] =
          normalized['asset_id'] ?? normalized['src'] ?? normalized['url'];
    }

    for (final key in const <String>[
      'children',
      'blocks',
      'items',
      'content',
    ]) {
      if (!normalized.containsKey(key)) {
        continue;
      }
      final nested = _normalizeBlocks(normalized[key]);
      if (nested.isEmpty) {
        normalized.remove(key);
      } else {
        normalized[key] = nested;
      }
    }

    final genericWrapperGroup = _normalizeGenericWrapperGroup(normalized);
    if (genericWrapperGroup != null) {
      return genericWrapperGroup;
    }

    if ((normalized['type'] == 'text' || normalized['type'] == 'latex') &&
        (normalized['text'] == null ||
            normalized['text'].toString().trim().isEmpty)) {
      final fallbackText =
          (normalized['label'] ?? normalized['value'] ?? '').toString().trim();
      if (fallbackText.isNotEmpty) {
        normalized['text'] = fallbackText;
      }
    }

    return normalized;
  }

  Map<String, dynamic>? _normalizeGenericWrapperGroup(
    Map<String, dynamic> normalized,
  ) {
    if (normalized['type'] != 'text' && normalized['type'] != 'latex') {
      return null;
    }
    final existingText = normalized['text']?.toString().trim() ?? '';
    if (existingText.isNotEmpty) {
      return null;
    }

    for (final entry in normalized.entries) {
      final key = entry.key;
      if (_reservedWrapperKeys.contains(key) ||
          (entry.value is! List && entry.value is! Map<String, dynamic>)) {
        continue;
      }
      final children = _normalizeBlocks(entry.value);
      if (children.isEmpty) {
        continue;
      }
      final title =
          (normalized['title'] ?? normalized['label'] ?? _humanizeCamelKey(key))
              .toString()
              .trim();
      return <String, dynamic>{
        ...normalized,
        'type': 'group',
        'title': title,
        'children': children,
      }..remove(key);
    }
    return null;
  }

  static const Set<String> _reservedWrapperKeys = <String>{
    'type',
    'kind',
    'variant',
    'title',
    'label',
    'text',
    'value',
    'children',
    'blocks',
    'items',
    'content',
    'assetId',
    'asset_id',
    'src',
    'url',
    'caption',
    'alt',
    'headers',
    'rows',
    'bodyRows',
    'cells',
    'ordered',
    'listStyle',
    'listKind',
    'level',
    'separator',
  };

  String _humanizeCamelKey(String key) {
    return key
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAll('_', ' ')
        .trim();
  }

  String _inferBlockType(Map<String, dynamic> block) {
    if (block['rows'] is List ||
        block['headers'] is List ||
        block['bodyRows'] is List) {
      return 'table';
    }
    if (block['assetId'] != null ||
        block['asset_id'] != null ||
        block['src'] != null ||
        block['url'] != null ||
        (block['caption'] is String &&
            (block['caption'] as String).trim().isNotEmpty) ||
        (block['alt'] is String &&
            (block['alt'] as String).trim().isNotEmpty)) {
      return 'image';
    }
    if (block['ordered'] is bool ||
        block['list'] is List ||
        block['bullets'] is List ||
        block['listStyle'] != null ||
        block['listKind'] != null) {
      return 'list';
    }
    if (block['timeline'] is List ||
        block['events'] is List ||
        block['entries'] is List ||
        block['date'] != null ||
        block['time'] != null ||
        block['variant'] == 'timeline' ||
        block['kind'] == 'timeline' ||
        block['kind'] == 'event') {
      return 'timeline';
    }
    if (block['stats'] is List ||
        block['metrics'] is List ||
        (block['value'] != null &&
            (block['label'] != null || block['title'] != null)) ||
        block['variant'] == 'stats' ||
        block['variant'] == 'metric' ||
        block['kind'] == 'stats' ||
        block['kind'] == 'metric') {
      return 'stats';
    }
    if (block['chart'] is List ||
        block['series'] is List ||
        block['points'] is List ||
        block['variant'] == 'chart' ||
        block['variant'] == 'series' ||
        block['kind'] == 'chart' ||
        block['kind'] == 'series') {
      return 'chart';
    }
    if (block['tabs'] is List ||
        block['sections'] is List ||
        block['tab'] != null ||
        block['variant'] == 'tabs' ||
        block['variant'] == 'sectioned' ||
        block['kind'] == 'tabs' ||
        block['kind'] == 'tab') {
      return 'tabs';
    }
    if (block['comparison'] is List ||
        block['before'] != null ||
        block['after'] != null ||
        block['variant'] == 'comparison' ||
        block['variant'] == 'before-after' ||
        block['kind'] == 'comparison' ||
        block['kind'] == 'before-after') {
      return 'comparison';
    }
    if (block['matrix'] is List ||
        block['grid'] is List ||
        block['variant'] == 'matrix' ||
        block['variant'] == 'grid' ||
        block['kind'] == 'matrix' ||
        block['kind'] == 'grid') {
      return 'matrix';
    }
    if (block['flow'] is List ||
        block['process'] is List ||
        block['variant'] == 'flow' ||
        block['variant'] == 'process' ||
        block['kind'] == 'flow' ||
        block['kind'] == 'process') {
      return 'flow';
    }
    if (block['rubric'] is List ||
        block['criteria'] is List ||
        block['variant'] == 'rubric' ||
        block['variant'] == 'criteria' ||
        block['kind'] == 'rubric' ||
        block['kind'] == 'criteria') {
      return 'rubric';
    }
    if (block['decision'] is List ||
        block['branches'] is List ||
        block['variant'] == 'decision' ||
        block['variant'] == 'branches' ||
        block['kind'] == 'decision' ||
        block['kind'] == 'branch') {
      return 'decision';
    }
    if (block['legend'] is List ||
        block['key'] is List ||
        block['variant'] == 'legend' ||
        block['variant'] == 'key' ||
        block['kind'] == 'legend' ||
        block['kind'] == 'key') {
      return 'legend';
    }
    if (block['pairs'] is List ||
        block['attributes'] is List ||
        block['variant'] == 'pairs' ||
        block['variant'] == 'attributes' ||
        block['kind'] == 'pairs' ||
        block['kind'] == 'attribute') {
      return 'pairs';
    }
    if (block['schema'] is List ||
        block['map'] is List ||
        block['variant'] == 'schema' ||
        block['variant'] == 'map' ||
        block['kind'] == 'schema' ||
        block['kind'] == 'map') {
      return 'schema';
    }
    if (block['milestones'] is List ||
        block['checkpoints'] is List ||
        block['variant'] == 'milestones' ||
        block['variant'] == 'checkpoints' ||
        block['kind'] == 'milestone' ||
        block['kind'] == 'checkpoint') {
      return 'milestones';
    }
    if (block['badges'] is List ||
        block['chips'] is List ||
        block['variant'] == 'badges' ||
        block['variant'] == 'chips' ||
        block['kind'] == 'badge' ||
        block['kind'] == 'chip') {
      return 'badges';
    }
    if (block['references'] is List ||
        block['footnotes'] is List ||
        block['variant'] == 'references' ||
        block['variant'] == 'footnotes' ||
        block['kind'] == 'reference' ||
        block['kind'] == 'footnote') {
      return 'references';
    }
    if (block['highlights'] is List ||
        block['annotations'] is List ||
        block['variant'] == 'highlights' ||
        block['variant'] == 'annotations' ||
        block['kind'] == 'highlight' ||
        block['kind'] == 'annotation') {
      return 'highlights';
    }
    if (block['outline'] is List ||
        block['syllabus'] is List ||
        block['variant'] == 'outline' ||
        block['variant'] == 'syllabus' ||
        block['kind'] == 'outline' ||
        block['kind'] == 'syllabus') {
      return 'outline';
    }
    if (block['warnings'] is List ||
        block['alerts'] is List ||
        block['variant'] == 'warnings' ||
        block['variant'] == 'alerts' ||
        block['kind'] == 'warning' ||
        block['kind'] == 'alert') {
      return 'warnings';
    }
    if (block['pitfalls'] is List ||
        block['misconceptions'] is List ||
        block['variant'] == 'pitfalls' ||
        block['variant'] == 'misconceptions' ||
        block['kind'] == 'pitfall' ||
        block['kind'] == 'misconception') {
      return 'pitfalls';
    }
    if (block['glossary'] is List ||
        block['terms'] is List ||
        block['variant'] == 'glossary' ||
        block['variant'] == 'terms' ||
        block['kind'] == 'glossary' ||
        block['kind'] == 'term') {
      return 'glossary';
    }
    if (block['examples'] is List ||
        block['samples'] is List ||
        block['variant'] == 'examples' ||
        block['variant'] == 'samples' ||
        block['kind'] == 'example' ||
        block['kind'] == 'sample') {
      return 'examples';
    }
    if (block['tips'] is List ||
        block['hints'] is List ||
        block['variant'] == 'tips' ||
        block['variant'] == 'hints' ||
        block['kind'] == 'tip' ||
        block['kind'] == 'hint') {
      return 'tips';
    }
    if (block['objectives'] is List ||
        block['goals'] is List ||
        block['variant'] == 'objectives' ||
        block['variant'] == 'goals' ||
        block['kind'] == 'objective' ||
        block['kind'] == 'goal') {
      return 'objectives';
    }
    if (block['prerequisites'] is List ||
        block['requirements'] is List ||
        block['variant'] == 'prerequisites' ||
        block['variant'] == 'requirements' ||
        block['kind'] == 'prerequisite' ||
        block['kind'] == 'requirement') {
      return 'prerequisites';
    }
    if (block['materials'] is List ||
        block['resources'] is List ||
        block['variant'] == 'materials' ||
        block['variant'] == 'resources' ||
        block['kind'] == 'material' ||
        block['kind'] == 'resource') {
      return 'materials';
    }
    if (block['constraints'] is List ||
        block['rules'] is List ||
        block['variant'] == 'constraints' ||
        block['variant'] == 'rules' ||
        block['kind'] == 'constraint' ||
        block['kind'] == 'rule') {
      return 'constraints';
    }
    if (block['notes'] is List ||
        block['remarks'] is List ||
        block['variant'] == 'notes' ||
        block['variant'] == 'remarks' ||
        block['kind'] == 'note-item' ||
        block['kind'] == 'remark') {
      return 'notes';
    }
    if (block['takeaways'] is List ||
        block['insights'] is List ||
        block['variant'] == 'takeaways' ||
        block['variant'] == 'insights' ||
        block['kind'] == 'takeaway' ||
        block['kind'] == 'insight') {
      return 'takeaways';
    }
    if (block['activities'] is List ||
        block['drills'] is List ||
        block['variant'] == 'activities' ||
        block['variant'] == 'drills' ||
        block['kind'] == 'activity' ||
        block['kind'] == 'drill') {
      return 'activities';
    }
    if (block['strategies'] is List ||
        block['approaches'] is List ||
        block['variant'] == 'strategies' ||
        block['variant'] == 'approaches' ||
        block['kind'] == 'strategy' ||
        block['kind'] == 'approach') {
      return 'strategies';
    }
    if (block['checks'] is List ||
        block['validations'] is List ||
        block['variant'] == 'checks' ||
        block['variant'] == 'validations' ||
        block['kind'] == 'check' ||
        block['kind'] == 'validation') {
      return 'checks';
    }
    if (block['heuristics'] is List ||
        block['rulesOfThumb'] is List ||
        block['variant'] == 'heuristics' ||
        block['variant'] == 'rules-of-thumb' ||
        block['kind'] == 'heuristic' ||
        block['kind'] == 'rule-of-thumb') {
      return 'heuristics';
    }
    if (block['signals'] is List ||
        block['indicators'] is List ||
        block['variant'] == 'signals' ||
        block['variant'] == 'indicators' ||
        block['kind'] == 'signal' ||
        block['kind'] == 'indicator') {
      return 'signals';
    }
    if (block['evidence'] is List ||
        block['proofs'] is List ||
        block['variant'] == 'evidence' ||
        block['variant'] == 'proofs' ||
        block['kind'] == 'evidence' ||
        block['kind'] == 'proof') {
      return 'evidence';
    }
    if (block['counterexamples'] is List ||
        block['nonExamples'] is List ||
        block['variant'] == 'counterexamples' ||
        block['variant'] == 'non-examples' ||
        block['kind'] == 'counterexample' ||
        block['kind'] == 'non-example') {
      return 'counterexamples';
    }
    if (block['patterns'] is List ||
        block['motifs'] is List ||
        block['variant'] == 'patterns' ||
        block['variant'] == 'motifs' ||
        block['kind'] == 'pattern' ||
        block['kind'] == 'motif') {
      return 'patterns';
    }
    if (block['variations'] is List ||
        block['scenarios'] is List ||
        block['variant'] == 'variations' ||
        block['variant'] == 'scenarios' ||
        block['kind'] == 'variation' ||
        block['kind'] == 'scenario') {
      return 'variations';
    }
    if (block['prompts'] is List ||
        block['cues'] is List ||
        block['variant'] == 'prompts' ||
        block['variant'] == 'cues' ||
        block['kind'] == 'prompt' ||
        block['kind'] == 'cue') {
      return 'prompts';
    }
    if (block['outcomes'] is List ||
        block['results'] is List ||
        block['variant'] == 'outcomes' ||
        block['variant'] == 'results' ||
        block['kind'] == 'outcome' ||
        block['kind'] == 'result') {
      return 'outcomes';
    }
    if (block['principles'] is List ||
        block['guidelines'] is List ||
        block['variant'] == 'principles' ||
        block['variant'] == 'guidelines' ||
        block['kind'] == 'principle' ||
        block['kind'] == 'guideline') {
      return 'principles';
    }
    if (block['phases'] is List ||
        block['segments'] is List ||
        block['variant'] == 'phases' ||
        block['variant'] == 'segments' ||
        block['kind'] == 'phase' ||
        block['kind'] == 'segment') {
      return 'phases';
    }
    if (block['anchors'] is List ||
        block['checkpoints'] is List ||
        block['variant'] == 'anchors' ||
        block['variant'] == 'checkpoints' ||
        block['kind'] == 'anchor' ||
        block['kind'] == 'checkpoint') {
      return 'anchors';
    }
    if (block['priorities'] is List ||
        block['focuses'] is List ||
        block['variant'] == 'priorities' ||
        block['variant'] == 'focuses' ||
        block['kind'] == 'priority' ||
        block['kind'] == 'focus') {
      return 'priorities';
    }
    if (block['assumptions'] is List ||
        block['assumptionsList'] is List ||
        block['variant'] == 'assumptions' ||
        block['variant'] == 'assumptionsList' ||
        block['kind'] == 'assumption') {
      return 'assumptions';
    }
    if (block['dependencies'] is List ||
        block['dependenciesList'] is List ||
        block['variant'] == 'dependencies' ||
        block['variant'] == 'dependenciesList' ||
        block['kind'] == 'dependency') {
      return 'dependencies';
    }
    if (block['tradeoffs'] is List ||
        block['prosAndCons'] is List ||
        block['variant'] == 'tradeoffs' ||
        block['variant'] == 'prosAndCons' ||
        block['kind'] == 'tradeoff') {
      return 'tradeoffs';
    }
    if (block['alternatives'] is List ||
        block['options'] is List ||
        block['variant'] == 'alternatives' ||
        block['variant'] == 'options' ||
        block['kind'] == 'alternative' ||
        block['kind'] == 'option') {
      return 'alternatives';
    }
    if (block['recommendations'] is List ||
        block['nextSteps'] is List ||
        block['variant'] == 'recommendations' ||
        block['variant'] == 'nextSteps' ||
        block['kind'] == 'recommendation' ||
        block['kind'] == 'nextStep') {
      return 'recommendations';
    }
    if (block['risks'] is List ||
        block['mitigations'] is List ||
        block['variant'] == 'risks' ||
        block['variant'] == 'mitigations' ||
        block['kind'] == 'risk' ||
        block['kind'] == 'mitigation') {
      return 'risks';
    }
    if (block['triggers'] is List ||
        block['conditions'] is List ||
        block['variant'] == 'triggers' ||
        block['variant'] == 'conditions' ||
        block['kind'] == 'trigger' ||
        block['kind'] == 'condition') {
      return 'triggers';
    }
    if (block['thresholds'] is List ||
        block['tolerances'] is List ||
        block['variant'] == 'thresholds' ||
        block['variant'] == 'tolerances' ||
        block['kind'] == 'threshold' ||
        block['kind'] == 'tolerance') {
      return 'thresholds';
    }
    if (block['edgeCases'] is List ||
        block['exceptions'] is List ||
        block['variant'] == 'edgeCases' ||
        block['variant'] == 'exceptions' ||
        block['kind'] == 'edgeCase' ||
        block['kind'] == 'exception') {
      return 'edgeCases';
    }
    if (block['flags'] is List ||
        block['variant'] == 'flags' ||
        block['kind'] == 'flag') {
      return 'flags';
    }
    if (block['reviewPoints'] is List ||
        block['reviewChecklist'] is List ||
        block['variant'] == 'reviewPoints' ||
        block['variant'] == 'reviewChecklist' ||
        block['kind'] == 'reviewPoint' ||
        block['kind'] == 'reviewChecklist') {
      return 'reviewPoints';
    }
    if (block['antiPatterns'] is List ||
        block['badPractices'] is List ||
        block['variant'] == 'antiPatterns' ||
        block['variant'] == 'badPractices' ||
        block['kind'] == 'antiPattern' ||
        block['kind'] == 'badPractice') {
      return 'antiPatterns';
    }
    if (block['dosAndDonts'] is Map ||
        block['guardrails'] is List ||
        block['variant'] == 'dosAndDonts' ||
        block['variant'] == 'guardrails' ||
        block['kind'] == 'guardrail') {
      return 'dosAndDonts';
    }
    if (block['watchFors'] is List ||
        block['cuesToMonitor'] is List ||
        block['variant'] == 'watchFors' ||
        block['variant'] == 'cuesToMonitor' ||
        block['kind'] == 'watchFor' ||
        block['kind'] == 'cueToMonitor') {
      return 'watchFors';
    }
    if (block['successCriteria'] is List ||
        block['exitCriteria'] is List ||
        block['variant'] == 'successCriteria' ||
        block['variant'] == 'exitCriteria' ||
        block['kind'] == 'successCriterion' ||
        block['kind'] == 'exitCriterion') {
      return 'successCriteria';
    }
    if (block['failureModes'] is List ||
        block['preMortem'] is List ||
        block['variant'] == 'failureModes' ||
        block['variant'] == 'preMortem' ||
        block['kind'] == 'failureMode' ||
        block['kind'] == 'preMortem') {
      return 'failureModes';
    }
    if (block['decisionCriteria'] is List ||
        block['selectionCriteria'] is List ||
        block['variant'] == 'decisionCriteria' ||
        block['variant'] == 'selectionCriteria' ||
        block['kind'] == 'decisionCriterion' ||
        block['kind'] == 'selectionCriterion') {
      return 'decisionCriteria';
    }
    if (block['goNoGo'] is List ||
        block['readinessSignals'] is List ||
        block['goNoGoChecks'] is List ||
        block['variant'] == 'goNoGo' ||
        block['variant'] == 'readinessSignals' ||
        block['kind'] == 'goNoGo' ||
        block['kind'] == 'readinessSignal') {
      return 'goNoGo';
    }
    if (block['alignment'] is List ||
        block['consistencyChecks'] is List ||
        block['variant'] == 'alignment' ||
        block['variant'] == 'consistencyChecks' ||
        block['kind'] == 'alignment' ||
        block['kind'] == 'consistencyCheck') {
      return 'alignment';
    }
    if (block['roles'] is List ||
        block['responsibilities'] is List ||
        block['variant'] == 'roles' ||
        block['variant'] == 'responsibilities' ||
        block['kind'] == 'role' ||
        block['kind'] == 'responsibility') {
      return 'roles';
    }
    if (block['stakeholders'] is List ||
        block['participants'] is List ||
        block['variant'] == 'stakeholders' ||
        block['variant'] == 'participants' ||
        block['kind'] == 'stakeholder' ||
        block['kind'] == 'participant') {
      return 'stakeholders';
    }
    if (block['owners'] is List ||
        block['ownership'] is List ||
        block['variant'] == 'owners' ||
        block['variant'] == 'ownership' ||
        block['kind'] == 'owner' ||
        block['kind'] == 'ownership') {
      return 'owners';
    }
    if (block['coverage'] is List ||
        block['scope'] is List ||
        block['variant'] == 'coverage' ||
        block['variant'] == 'scope' ||
        block['kind'] == 'coverage' ||
        block['kind'] == 'scope') {
      return 'coverage';
    }
    if (block['inputs'] is List ||
        block['outputs'] is List ||
        block['variant'] == 'inputs' ||
        block['variant'] == 'outputs' ||
        block['kind'] == 'input' ||
        block['kind'] == 'output') {
      return 'inputsOutputs';
    }
    if (block['preconditions'] is List ||
        block['postconditions'] is List ||
        block['variant'] == 'preconditions' ||
        block['variant'] == 'postconditions' ||
        block['kind'] == 'precondition' ||
        block['kind'] == 'postcondition') {
      return 'conditions';
    }
    if (block['artifacts'] is List ||
        block['deliverables'] is List ||
        block['variant'] == 'artifacts' ||
        block['variant'] == 'deliverables' ||
        block['kind'] == 'artifact' ||
        block['kind'] == 'deliverable') {
      return 'artifacts';
    }
    if (block['handoverNotes'] is List ||
        block['operatorNotes'] is List ||
        block['variant'] == 'handoverNotes' ||
        block['variant'] == 'operatorNotes' ||
        block['kind'] == 'handoverNote' ||
        block['kind'] == 'operatorNote') {
      return 'handoverNotes';
    }
    if (block['acceptance'] is List ||
        block['signoff'] is List ||
        block['variant'] == 'acceptance' ||
        block['variant'] == 'signoff' ||
        block['kind'] == 'acceptance' ||
        block['kind'] == 'signoff') {
      return 'acceptance';
    }
    if (block['followUpOwners'] is List ||
        block['actionOwners'] is List ||
        block['variant'] == 'followUpOwners' ||
        block['variant'] == 'actionOwners' ||
        block['kind'] == 'followUpOwner' ||
        block['kind'] == 'actionOwner') {
      return 'followUpOwners';
    }
    if (block['verification'] is List ||
        block['auditChecks'] is List ||
        block['variant'] == 'verification' ||
        block['variant'] == 'auditChecks' ||
        block['kind'] == 'verification' ||
        block['kind'] == 'auditCheck') {
      return 'verification';
    }
    if (block['serviceLevels'] is List ||
        block['responseExpectations'] is List ||
        block['variant'] == 'serviceLevels' ||
        block['variant'] == 'responseExpectations' ||
        block['kind'] == 'serviceLevel' ||
        block['kind'] == 'responseExpectation') {
      return 'serviceLevels';
    }
    if (block['escalations'] is List ||
        block['escalationPaths'] is List ||
        block['variant'] == 'escalations' ||
        block['variant'] == 'escalationPaths' ||
        block['kind'] == 'escalation' ||
        block['kind'] == 'escalationPath') {
      return 'escalations';
    }
    if (block['escalationContacts'] is List ||
        block['escalationOwners'] is List ||
        block['variant'] == 'escalationContacts' ||
        block['variant'] == 'escalationOwners' ||
        block['kind'] == 'escalationContact' ||
        block['kind'] == 'escalationOwner') {
      return 'escalationContacts';
    }
    if (block['reviewCadence'] is List ||
        block['syncCadence'] is List ||
        block['variant'] == 'reviewCadence' ||
        block['variant'] == 'syncCadence' ||
        block['kind'] == 'reviewCadence' ||
        block['kind'] == 'syncCadence') {
      return 'reviewCadence';
    }
    if (block['notificationPaths'] is List ||
        block['alertsRouting'] is List ||
        block['variant'] == 'notificationPaths' ||
        block['variant'] == 'alertsRouting' ||
        block['kind'] == 'notificationPath' ||
        block['kind'] == 'alertsRouting') {
      return 'notificationPaths';
    }
    if (block['notifyTriggers'] is List ||
        block['alertTriggers'] is List ||
        block['variant'] == 'notifyTriggers' ||
        block['variant'] == 'alertTriggers' ||
        block['kind'] == 'notifyTrigger' ||
        block['kind'] == 'alertTrigger') {
      return 'notifyTriggers';
    }
    if (block['responsePriorities'] is List ||
        block['triagePriorities'] is List ||
        block['variant'] == 'responsePriorities' ||
        block['variant'] == 'triagePriorities' ||
        block['kind'] == 'responsePriority' ||
        block['kind'] == 'triagePriority') {
      return 'responsePriorities';
    }
    if (block['responseWindows'] is List ||
        block['escalationWindows'] is List ||
        block['variant'] == 'responseWindows' ||
        block['variant'] == 'escalationWindows' ||
        block['kind'] == 'responseWindow' ||
        block['kind'] == 'escalationWindow') {
      return 'responseWindows';
    }
    if (block['notificationWindows'] is List ||
        block['alertWindows'] is List ||
        block['variant'] == 'notificationWindows' ||
        block['variant'] == 'alertWindows' ||
        block['kind'] == 'notificationWindow' ||
        block['kind'] == 'alertWindow') {
      return 'notificationWindows';
    }
    if (block['notificationRecipients'] is List ||
        block['alertRecipients'] is List ||
        block['variant'] == 'notificationRecipients' ||
        block['variant'] == 'alertRecipients' ||
        block['kind'] == 'notificationRecipient' ||
        block['kind'] == 'alertRecipient') {
      return 'notificationRecipients';
    }
    if (block['notificationPayloads'] is List ||
        block['alertPayloads'] is List ||
        block['variant'] == 'notificationPayloads' ||
        block['variant'] == 'alertPayloads' ||
        block['kind'] == 'notificationPayload' ||
        block['kind'] == 'alertPayload') {
      return 'notificationPayloads';
    }
    if (block['notificationOutcomes'] is List ||
        block['alertOutcomes'] is List ||
        block['variant'] == 'notificationOutcomes' ||
        block['variant'] == 'alertOutcomes' ||
        block['kind'] == 'notificationOutcome' ||
        block['kind'] == 'alertOutcome') {
      return 'notificationOutcomes';
    }
    if (block['notificationFailures'] is List ||
        block['alertFailures'] is List ||
        block['variant'] == 'notificationFailures' ||
        block['variant'] == 'alertFailures' ||
        block['kind'] == 'notificationFailure' ||
        block['kind'] == 'alertFailure') {
      return 'notificationFailures';
    }
    if (block['notificationChecks'] is List ||
        block['alertChecks'] is List ||
        block['variant'] == 'notificationChecks' ||
        block['variant'] == 'alertChecks' ||
        block['kind'] == 'notificationCheck' ||
        block['kind'] == 'alertCheck') {
      return 'notificationChecks';
    }
    if (block['notificationDependencies'] is List ||
        block['alertDependencies'] is List ||
        block['variant'] == 'notificationDependencies' ||
        block['variant'] == 'alertDependencies' ||
        block['kind'] == 'notificationDependency' ||
        block['kind'] == 'alertDependency') {
      return 'notificationDependencies';
    }
    if (block['notificationDecisions'] is List ||
        block['alertDecisions'] is List ||
        block['variant'] == 'notificationDecisions' ||
        block['variant'] == 'alertDecisions' ||
        block['kind'] == 'notificationDecision' ||
        block['kind'] == 'alertDecision') {
      return 'notificationDecisions';
    }
    if (block['notificationSummaries'] is List ||
        block['alertSummaries'] is List ||
        block['variant'] == 'notificationSummaries' ||
        block['variant'] == 'alertSummaries' ||
        block['kind'] == 'notificationSummary' ||
        block['kind'] == 'alertSummary') {
      return 'notificationSummaries';
    }
    if (block['notificationMetrics'] is List ||
        block['alertMetrics'] is List ||
        block['variant'] == 'notificationMetrics' ||
        block['variant'] == 'alertMetrics' ||
        block['kind'] == 'notificationMetric' ||
        block['kind'] == 'alertMetric') {
      return 'notificationMetrics';
    }
    if (block['notificationAudits'] is List ||
        block['alertAudits'] is List ||
        block['variant'] == 'notificationAudits' ||
        block['variant'] == 'alertAudits' ||
        block['kind'] == 'notificationAudit' ||
        block['kind'] == 'alertAudit') {
      return 'notificationAudits';
    }
    if (block['notificationPolicies'] is List ||
        block['alertPolicies'] is List ||
        block['variant'] == 'notificationPolicies' ||
        block['variant'] == 'alertPolicies' ||
        block['kind'] == 'notificationPolicy' ||
        block['kind'] == 'alertPolicy') {
      return 'notificationPolicies';
    }
    if (block['notificationChannels'] is List ||
        block['alertChannels'] is List ||
        block['variant'] == 'notificationChannels' ||
        block['variant'] == 'alertChannels' ||
        block['kind'] == 'notificationChannel' ||
        block['kind'] == 'alertChannel') {
      return 'notificationChannels';
    }
    if (block['notificationOwners'] is List ||
        block['alertOwners'] is List ||
        block['variant'] == 'notificationOwners' ||
        block['variant'] == 'alertOwners' ||
        block['kind'] == 'notificationOwner' ||
        block['kind'] == 'alertOwner') {
      return 'notificationOwners';
    }
    if (block['notificationEscalations'] is List ||
        block['alertEscalations'] is List ||
        block['variant'] == 'notificationEscalations' ||
        block['variant'] == 'alertEscalations' ||
        block['kind'] == 'notificationEscalation' ||
        block['kind'] == 'alertEscalation') {
      return 'notificationEscalations';
    }
    if (block['notificationTemplates'] is List ||
        block['alertTemplates'] is List ||
        block['variant'] == 'notificationTemplates' ||
        block['variant'] == 'alertTemplates' ||
        block['kind'] == 'notificationTemplate' ||
        block['kind'] == 'alertTemplate') {
      return 'notificationTemplates';
    }
    if (block['notificationApprovals'] is List ||
        block['alertApprovals'] is List ||
        block['variant'] == 'notificationApprovals' ||
        block['variant'] == 'alertApprovals' ||
        block['kind'] == 'notificationApproval' ||
        block['kind'] == 'alertApproval') {
      return 'notificationApprovals';
    }
    if (block['notificationStates'] is List ||
        block['alertStates'] is List ||
        block['variant'] == 'notificationStates' ||
        block['variant'] == 'alertStates' ||
        block['kind'] == 'notificationState' ||
        block['kind'] == 'alertState') {
      return 'notificationStates';
    }
    if (block['notificationHistory'] is List ||
        block['alertHistory'] is List ||
        block['variant'] == 'notificationHistory' ||
        block['variant'] == 'alertHistory' ||
        block['kind'] == 'notificationHistory' ||
        block['kind'] == 'alertHistory') {
      return 'notificationHistory';
    }
    if (block['notificationRetries'] is List ||
        block['alertRetries'] is List ||
        block['variant'] == 'notificationRetries' ||
        block['variant'] == 'alertRetries' ||
        block['kind'] == 'notificationRetry' ||
        block['kind'] == 'alertRetry') {
      return 'notificationRetries';
    }
    if (block['notificationFallbacks'] is List ||
        block['alertFallbacks'] is List ||
        block['variant'] == 'notificationFallbacks' ||
        block['variant'] == 'alertFallbacks' ||
        block['kind'] == 'notificationFallback' ||
        block['kind'] == 'alertFallback') {
      return 'notificationFallbacks';
    }
    if (block['notificationExceptions'] is List ||
        block['alertExceptions'] is List ||
        block['variant'] == 'notificationExceptions' ||
        block['variant'] == 'alertExceptions' ||
        block['kind'] == 'notificationException' ||
        block['kind'] == 'alertException') {
      return 'notificationExceptions';
    }
    if (block['notificationOverrides'] is List ||
        block['alertOverrides'] is List ||
        block['variant'] == 'notificationOverrides' ||
        block['variant'] == 'alertOverrides' ||
        block['kind'] == 'notificationOverride' ||
        block['kind'] == 'alertOverride') {
      return 'notificationOverrides';
    }
    if (block['notificationGuardrails'] is List ||
        block['alertGuardrails'] is List ||
        block['variant'] == 'notificationGuardrails' ||
        block['variant'] == 'alertGuardrails' ||
        block['kind'] == 'notificationGuardrail' ||
        block['kind'] == 'alertGuardrail') {
      return 'notificationGuardrails';
    }
    if (block['notificationPrereqs'] is List ||
        block['alertPrereqs'] is List ||
        block['variant'] == 'notificationPrereqs' ||
        block['variant'] == 'alertPrereqs' ||
        block['kind'] == 'notificationPrereq' ||
        block['kind'] == 'alertPrereq') {
      return 'notificationPrereqs';
    }
    if (block['notificationAudienceRules'] is List ||
        block['alertAudienceRules'] is List ||
        block['variant'] == 'notificationAudienceRules' ||
        block['variant'] == 'alertAudienceRules' ||
        block['kind'] == 'notificationAudienceRule' ||
        block['kind'] == 'alertAudienceRule') {
      return 'notificationAudienceRules';
    }
    if (block['notificationVariants'] is List ||
        block['alertVariants'] is List ||
        block['variant'] == 'notificationVariants' ||
        block['variant'] == 'alertVariants' ||
        block['kind'] == 'notificationVariant' ||
        block['kind'] == 'alertVariant') {
      return 'notificationVariants';
    }
    if (block['notificationCadences'] is List ||
        block['alertCadences'] is List ||
        block['variant'] == 'notificationCadences' ||
        block['variant'] == 'alertCadences' ||
        block['kind'] == 'notificationCadence' ||
        block['kind'] == 'alertCadence') {
      return 'notificationCadences';
    }
    if (block['notificationScopes'] is List ||
        block['alertScopes'] is List ||
        block['variant'] == 'notificationScopes' ||
        block['variant'] == 'alertScopes' ||
        block['kind'] == 'notificationScope' ||
        block['kind'] == 'alertScope') {
      return 'notificationScopes';
    }
    if (block['notificationBundles'] is List ||
        block['alertBundles'] is List ||
        block['variant'] == 'notificationBundles' ||
        block['variant'] == 'alertBundles' ||
        block['kind'] == 'notificationBundle' ||
        block['kind'] == 'alertBundle') {
      return 'notificationBundles';
    }
    if (block['notificationExclusions'] is List ||
        block['alertExclusions'] is List ||
        block['variant'] == 'notificationExclusions' ||
        block['variant'] == 'alertExclusions' ||
        block['kind'] == 'notificationExclusion' ||
        block['kind'] == 'alertExclusion') {
      return 'notificationExclusions';
    }
    if (block['notificationThresholds'] is List ||
        block['alertThresholds'] is List ||
        block['variant'] == 'notificationThresholds' ||
        block['variant'] == 'alertThresholds' ||
        block['kind'] == 'notificationThreshold' ||
        block['kind'] == 'alertThreshold') {
      return 'notificationThresholds';
    }
    if (block['notificationMatrices'] is List ||
        block['alertMatrices'] is List ||
        block['variant'] == 'notificationMatrices' ||
        block['variant'] == 'alertMatrices' ||
        block['kind'] == 'notificationMatrix' ||
        block['kind'] == 'alertMatrix') {
      return 'notificationMatrices';
    }
    if (block['notificationSequences'] is List ||
        block['alertSequences'] is List ||
        block['variant'] == 'notificationSequences' ||
        block['variant'] == 'alertSequences' ||
        block['kind'] == 'notificationSequence' ||
        block['kind'] == 'alertSequence') {
      return 'notificationSequences';
    }
    if (block['notificationPoliciesets'] is List ||
        block['alertPoliciesets'] is List ||
        block['variant'] == 'notificationPoliciesets' ||
        block['variant'] == 'alertPoliciesets' ||
        block['kind'] == 'notificationPolicieset' ||
        block['kind'] == 'alertPolicieset') {
      return 'notificationPoliciesets';
    }
    if (block['notificationPlaybooks'] is List ||
        block['alertPlaybooks'] is List ||
        block['variant'] == 'notificationPlaybooks' ||
        block['variant'] == 'alertPlaybooks' ||
        block['kind'] == 'notificationPlaybook' ||
        block['kind'] == 'alertPlaybook') {
      return 'notificationPlaybooks';
    }
    if (block['notificationBundlesets'] is List ||
        block['alertBundlesets'] is List ||
        block['variant'] == 'notificationBundlesets' ||
        block['variant'] == 'alertBundlesets' ||
        block['kind'] == 'notificationBundleset' ||
        block['kind'] == 'alertBundleset') {
      return 'notificationBundlesets';
    }
    if (block['notificationCheckpoints'] is List ||
        block['alertCheckpoints'] is List ||
        block['variant'] == 'notificationCheckpoints' ||
        block['variant'] == 'alertCheckpoints' ||
        block['kind'] == 'notificationCheckpoint' ||
        block['kind'] == 'alertCheckpoint') {
      return 'notificationCheckpoints';
    }
    if (block['notificationHandshakes'] is List ||
        block['alertHandshakes'] is List ||
        block['variant'] == 'notificationHandshakes' ||
        block['variant'] == 'alertHandshakes' ||
        block['kind'] == 'notificationHandshake' ||
        block['kind'] == 'alertHandshake') {
      return 'notificationHandshakes';
    }
    if (block['notificationAcknowledgements'] is List ||
        block['alertAcknowledgements'] is List ||
        block['variant'] == 'notificationAcknowledgements' ||
        block['variant'] == 'alertAcknowledgements' ||
        block['kind'] == 'notificationAcknowledgement' ||
        block['kind'] == 'alertAcknowledgement') {
      return 'notificationAcknowledgements';
    }
    if (block['notificationEvidence'] is List ||
        block['alertEvidence'] is List ||
        block['variant'] == 'notificationEvidence' ||
        block['variant'] == 'alertEvidence' ||
        block['kind'] == 'notificationEvidence' ||
        block['kind'] == 'alertEvidence') {
      return 'notificationEvidence';
    }
    if (block['notificationRisks'] is List ||
        block['alertRisks'] is List ||
        block['variant'] == 'notificationRisks' ||
        block['variant'] == 'alertRisks' ||
        block['kind'] == 'notificationRisk' ||
        block['kind'] == 'alertRisk') {
      return 'notificationRisks';
    }
    if (block['notificationRecoveries'] is List ||
        block['alertRecoveries'] is List ||
        block['variant'] == 'notificationRecoveries' ||
        block['variant'] == 'alertRecoveries' ||
        block['kind'] == 'notificationRecovery' ||
        block['kind'] == 'alertRecovery') {
      return 'notificationRecoveries';
    }
    if (block['notificationImpacts'] is List ||
        block['alertImpacts'] is List ||
        block['variant'] == 'notificationImpacts' ||
        block['variant'] == 'alertImpacts' ||
        block['kind'] == 'notificationImpact' ||
        block['kind'] == 'alertImpact') {
      return 'notificationImpacts';
    }
    if (block['notificationDependenciesMap'] is List ||
        block['alertDependenciesMap'] is List ||
        block['variant'] == 'notificationDependenciesMap' ||
        block['variant'] == 'alertDependenciesMap' ||
        block['kind'] == 'notificationDependencyMap' ||
        block['kind'] == 'alertDependencyMap') {
      return 'notificationDependenciesMap';
    }
    if (block['notificationOwnersMap'] is List ||
        block['alertOwnersMap'] is List ||
        block['variant'] == 'notificationOwnersMap' ||
        block['variant'] == 'alertOwnersMap' ||
        block['kind'] == 'notificationOwnerMap' ||
        block['kind'] == 'alertOwnerMap') {
      return 'notificationOwnersMap';
    }
    if (block['notificationDecisionsLog'] is List ||
        block['alertDecisionsLog'] is List ||
        block['variant'] == 'notificationDecisionsLog' ||
        block['variant'] == 'alertDecisionsLog' ||
        block['kind'] == 'notificationDecisionLog' ||
        block['kind'] == 'alertDecisionLog') {
      return 'notificationDecisionsLog';
    }
    if (block['notificationStateChanges'] is List ||
        block['alertStateChanges'] is List ||
        block['variant'] == 'notificationStateChanges' ||
        block['variant'] == 'alertStateChanges' ||
        block['kind'] == 'notificationStateChange' ||
        block['kind'] == 'alertStateChange') {
      return 'notificationStateChanges';
    }
    if (block['notificationReadiness'] is List ||
        block['alertReadiness'] is List ||
        block['variant'] == 'notificationReadiness' ||
        block['variant'] == 'alertReadiness' ||
        block['kind'] == 'notificationReadiness' ||
        block['kind'] == 'alertReadiness') {
      return 'notificationReadiness';
    }
    if (block['notificationCoverageChecks'] is List ||
        block['alertCoverageChecks'] is List ||
        block['variant'] == 'notificationCoverageChecks' ||
        block['variant'] == 'alertCoverageChecks' ||
        block['kind'] == 'notificationCoverageCheck' ||
        block['kind'] == 'alertCoverageCheck') {
      return 'notificationCoverageChecks';
    }
    if (block['notificationConfirmations'] is List ||
        block['alertConfirmations'] is List ||
        block['variant'] == 'notificationConfirmations' ||
        block['variant'] == 'alertConfirmations' ||
        block['kind'] == 'notificationConfirmation' ||
        block['kind'] == 'alertConfirmation') {
      return 'notificationConfirmations';
    }
    if (block['notificationClosures'] is List ||
        block['alertClosures'] is List ||
        block['variant'] == 'notificationClosures' ||
        block['variant'] == 'alertClosures' ||
        block['kind'] == 'notificationClosure' ||
        block['kind'] == 'alertClosure') {
      return 'notificationClosures';
    }
    if (block['notificationExceptionsLog'] is List ||
        block['alertExceptionsLog'] is List ||
        block['variant'] == 'notificationExceptionsLog' ||
        block['variant'] == 'alertExceptionsLog' ||
        block['kind'] == 'notificationExceptionLog' ||
        block['kind'] == 'alertExceptionLog') {
      return 'notificationExceptionsLog';
    }
    if (block['notificationEscalationChecks'] is List ||
        block['alertEscalationChecks'] is List ||
        block['variant'] == 'notificationEscalationChecks' ||
        block['variant'] == 'alertEscalationChecks' ||
        block['kind'] == 'notificationEscalationCheck' ||
        block['kind'] == 'alertEscalationCheck') {
      return 'notificationEscalationChecks';
    }
    if (block['notificationRoutingDecisions'] is List ||
        block['alertRoutingDecisions'] is List ||
        block['variant'] == 'notificationRoutingDecisions' ||
        block['variant'] == 'alertRoutingDecisions' ||
        block['kind'] == 'notificationRoutingDecision' ||
        block['kind'] == 'alertRoutingDecision') {
      return 'notificationRoutingDecisions';
    }
    if (block['notificationDeliveryProofs'] is List ||
        block['alertDeliveryProofs'] is List ||
        block['variant'] == 'notificationDeliveryProofs' ||
        block['variant'] == 'alertDeliveryProofs' ||
        block['kind'] == 'notificationDeliveryProof' ||
        block['kind'] == 'alertDeliveryProof') {
      return 'notificationDeliveryProofs';
    }
    if (block['agenda'] is List ||
        block['schedule'] is List ||
        block['variant'] == 'agenda' ||
        block['variant'] == 'schedule' ||
        block['kind'] == 'agenda' ||
        block['kind'] == 'schedule') {
      return 'agenda';
    }
    if (block['corrections'] is List ||
        block['missteps'] is List ||
        block['variant'] == 'corrections' ||
        block['variant'] == 'missteps' ||
        block['kind'] == 'correction' ||
        block['kind'] == 'misstep') {
      return 'corrections';
    }
    if (block['facets'] is List ||
        block['dimensions'] is List ||
        block['variant'] == 'facets' ||
        block['variant'] == 'dimensions' ||
        block['kind'] == 'facet' ||
        block['kind'] == 'dimension') {
      return 'facets';
    }
    if (block['dialogue'] is List ||
        block['discussion'] is List ||
        block['variant'] == 'dialogue' ||
        block['variant'] == 'discussion' ||
        block['kind'] == 'dialogue' ||
        block['kind'] == 'discussion') {
      return 'dialogue';
    }
    if (block['observations'] is List ||
        block['findings'] is List ||
        block['variant'] == 'observations' ||
        block['variant'] == 'findings' ||
        block['kind'] == 'observation' ||
        block['kind'] == 'finding') {
      return 'observations';
    }
    if (block['actions'] is List ||
        block['moves'] is List ||
        block['variant'] == 'actions' ||
        block['variant'] == 'moves' ||
        block['kind'] == 'action' ||
        block['kind'] == 'move') {
      return 'actions';
    }
    if (block['transitions'] is List ||
        block['handoffs'] is List ||
        block['variant'] == 'transitions' ||
        block['variant'] == 'handoffs' ||
        block['kind'] == 'transition' ||
        block['kind'] == 'handoff') {
      return 'transitions';
    }
    if (block['accordion'] is List ||
        block['details'] is List ||
        block['summary'] != null ||
        block['variant'] == 'accordion' ||
        block['variant'] == 'details' ||
        block['kind'] == 'accordion' ||
        block['kind'] == 'details') {
      return 'accordion';
    }
    if (block['faq'] is List ||
        block['qa'] is List ||
        block['question'] != null ||
        block['answer'] != null ||
        block['variant'] == 'faq' ||
        block['variant'] == 'qa' ||
        block['kind'] == 'faq' ||
        block['kind'] == 'qa') {
      return 'qa';
    }
    if (block['quote'] != null ||
        block['variant'] == 'quote' ||
        block['kind'] == 'quote') {
      return 'quote';
    }
    if (block['callout'] != null ||
        block['note'] != null ||
        block['variant'] == 'callout' ||
        block['variant'] == 'note' ||
        block['kind'] == 'callout' ||
        block['kind'] == 'note') {
      return 'callout';
    }
    if (block['code'] != null ||
        block['snippet'] != null ||
        block['language'] != null ||
        block['variant'] == 'code' ||
        block['kind'] == 'code') {
      return 'code';
    }
    if (block['columns'] is List ||
        block['column'] is List ||
        block['variant'] == 'columns' ||
        block['kind'] == 'columns' ||
        block['kind'] == 'column') {
      return 'columns';
    }
    if (block['checklist'] is List ||
        block['tasks'] is List ||
        block['checked'] is bool ||
        block['variant'] == 'checklist' ||
        block['kind'] == 'checklist' ||
        block['kind'] == 'task') {
      return 'checklist';
    }
    if (block['href'] != null ||
        block['link'] != null ||
        block['variant'] == 'link' ||
        block['kind'] == 'link') {
      return 'link';
    }
    if (block['step'] != null ||
        block['steps'] != null ||
        block['index'] is num ||
        block['variant'] == 'step' ||
        block['kind'] == 'step') {
      return 'step';
    }
    if (block['embed'] != null ||
        block['video'] != null ||
        block['audio'] != null ||
        block['mediaUrl'] != null ||
        block['variant'] == 'embed' ||
        block['variant'] == 'video' ||
        block['variant'] == 'audio' ||
        block['kind'] == 'embed' ||
        block['kind'] == 'video' ||
        block['kind'] == 'audio') {
      return 'embed';
    }
    if (block['divider'] == true ||
        block['separator'] == true ||
        block['variant'] == 'divider' ||
        block['kind'] == 'divider') {
      return 'divider';
    }
    if (block['heading'] != null ||
        block['title'] != null ||
        block['level'] is num ||
        block['variant'] == 'heading' ||
        block['kind'] == 'heading' ||
        block['kind'] == 'title') {
      return 'heading';
    }
    return 'text';
  }

  String _formatSourceText(Map<String, dynamic> source) {
    final parts = <String>[];
    final year = source['year'];
    final month = source['month'];
    final description = source['description'];

    if (year != null && '$year'.trim().isNotEmpty) {
      parts.add('$year年');
    }
    if (month != null && '$month'.trim().isNotEmpty) {
      parts.add('$month月');
    }
    if (description is String && description.trim().isNotEmpty) {
      parts.add(description.trim());
    }

    if (parts.isEmpty) {
      return '未标注出处';
    }
    return parts.join(' · ');
  }

  List<Map<String, dynamic>> _normalizeScoringPointBlocks(dynamic value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }
    final blocks = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is! Map) {
        continue;
      }
      final normalized = item.map(
        (key, itemValue) => MapEntry(key.toString(), itemValue),
      );
      final points = normalized['points'];
      final description = (normalized['description'] ?? '').toString().trim();
      final label = points is num ? '评分点（${points.toString()} 分）' : '评分点';
      if (description.isNotEmpty) {
        blocks.add(
            <String, dynamic>{'type': 'text', 'text': '$label：$description'});
      } else {
        blocks.add(<String, dynamic>{'type': 'text', 'text': label});
      }
    }
    return blocks;
  }

  dynamic _firstNonNull(
    Object? first, [
    Object? second,
    Object? third,
    Object? fourth,
    Object? fifth,
    Object? sixth,
    Object? seventh,
  ]) {
    for (final value in <Object?>[
      first,
      second,
      third,
      fourth,
      fifth,
      sixth,
      seventh,
    ]) {
      if (value == null) {
        continue;
      }
      if (value is String && value.trim().isEmpty) {
        continue;
      }
      if (value is List && value.isEmpty) {
        continue;
      }
      return value;
    }
    return null;
  }
}

List<QuestionSummary> _applyQuestionClientFilters(
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
    return matchesSubject && matchesStage && matchesTextbook && matchesQuery;
  }).toList();
}

List<Map<String, dynamic>> _textBlocks(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return const <Map<String, dynamic>>[];
  }
  return trimmed
      .split(RegExp(r'\n{2,}'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .map(
        (item) => <String, dynamic>{
          'type': 'text',
          'text': item,
        },
      )
      .toList(growable: false);
}

String _buildQuestionTitle(String stemText) {
  final trimmed = stemText.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (trimmed.isEmpty) {
    return '未命名题目';
  }
  const maxLength = 24;
  if (trimmed.length <= maxLength) {
    return trimmed;
  }
  return '${trimmed.substring(0, maxLength)}…';
}
