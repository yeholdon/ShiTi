import '../config/app_config.dart';
import '../models/auth_session.dart';
import '../models/document_item_summary.dart';
import '../models/export_job_summary.dart';
import '../models/document_summary.dart';
import '../models/library_filter_state.dart';
import '../models/layout_element_summary.dart';
import '../models/question_summary.dart';
import '../models/tenant_summary.dart';

class ShiTiApiClient {
  const ShiTiApiClient();

  static final List<TenantSummary> _tenants = <TenantSummary>[
    const TenantSummary(
      id: 'tenant-1',
      code: 'math-studio',
      name: '数学教研组',
      role: 'owner',
    ),
    const TenantSummary(
      id: 'tenant-2',
      code: 'junior-physics',
      name: '初中理化题库',
      role: 'admin',
    ),
    const TenantSummary(
      id: 'tenant-3',
      code: 'exam-lab',
      name: '中考冲刺专题库',
      role: 'member',
    ),
  ];

  static final List<DocumentSummary> _documents = <DocumentSummary>[
    const DocumentSummary(
      id: 'doc-1',
      name: '九上相似专题讲义',
      kind: 'handout',
      questionCount: 8,
      layoutCount: 3,
      latestExportStatus: 'succeeded',
    ),
    const DocumentSummary(
      id: 'doc-2',
      name: '二次函数周测卷',
      kind: 'paper',
      questionCount: 12,
      layoutCount: 0,
      latestExportStatus: 'pending',
    ),
  ];

  static final Map<String, List<DocumentItemSummary>> _documentItems =
      <String, List<DocumentItemSummary>>{
    'doc-1': <DocumentItemSummary>[
      const DocumentItemSummary(
        id: 'doc1-item-1',
        kind: 'layout',
        title: '导入说明',
        detail: '讲义页眉与课前提醒',
      ),
      const DocumentItemSummary(
        id: 'doc1-item-2',
        kind: 'question',
        title: '相似三角形综合题',
        detail: '例题 1 · 几何综合',
      ),
      const DocumentItemSummary(
        id: 'doc1-item-3',
        kind: 'layout',
        title: '课堂提问框',
        detail: '板书与留白区域',
      ),
    ],
    'doc-2': <DocumentItemSummary>[
      const DocumentItemSummary(
        id: 'doc2-item-1',
        kind: 'question',
        title: '函数图像与最值',
        detail: '第 1 题 · 二次函数',
      ),
      const DocumentItemSummary(
        id: 'doc2-item-2',
        kind: 'question',
        title: '相似三角形综合题',
        detail: '第 2 题 · 几何综合',
      ),
    ],
  };

  static final List<ExportJobSummary> _exportJobs = <ExportJobSummary>[
    const ExportJobSummary(
      id: 'job-1',
      documentName: '九上相似专题讲义',
      format: 'pdf',
      status: 'succeeded',
      updatedAtLabel: '刚刚',
    ),
    const ExportJobSummary(
      id: 'job-2',
      documentName: '二次函数周测卷',
      format: 'pdf',
      status: 'pending',
      updatedAtLabel: '2 分钟前',
    ),
    const ExportJobSummary(
      id: 'job-3',
      documentName: '浮力实验讲义',
      format: 'pdf',
      status: 'failed',
      updatedAtLabel: '今天 20:15',
    ),
  ];

  static const List<LayoutElementSummary> _layoutElements = <LayoutElementSummary>[
    LayoutElementSummary(
      id: 'layout-1',
      name: '课前导语',
      description: '用于讲义开头的引入说明和学习目标。',
    ),
    LayoutElementSummary(
      id: 'layout-2',
      name: '课堂提问框',
      description: '用于放置板书提示、提问留白和互动任务。',
    ),
    LayoutElementSummary(
      id: 'layout-3',
      name: '课后总结区',
      description: '用于讲义结尾总结和延伸作业提醒。',
    ),
  ];

  String get baseUrl => AppConfig.apiBaseUrl;

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));

    return AuthSession(
      userId: 'demo-user',
      username: username.trim().isEmpty ? 'demo_teacher' : username.trim(),
      accessLevel: 'member',
      accessToken: 'local-demo-token',
      tokenPreview: 'local-demo-token',
    );
  }

  Future<AuthSession> register({
    required String username,
    required String password,
  }) async {
    return login(username: username, password: password);
  }

  Future<List<TenantSummary>> listTenants() async {
    await Future<void>.delayed(const Duration(milliseconds: 220));

    return List<TenantSummary>.from(_tenants);
  }

  Future<TenantSummary> createTenant({
    required String code,
    required String name,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));

    for (final tenant in _tenants) {
      if (tenant.code == code) {
        return tenant;
      }
    }

    final tenant = TenantSummary(
      id: 'tenant-${DateTime.now().millisecondsSinceEpoch}',
      code: code,
      name: name,
      role: 'owner',
    );
    _tenants.insert(0, tenant);
    return tenant;
  }

  Future<List<QuestionSummary>> listQuestions({
    LibraryFilterState filters = const LibraryFilterState(),
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));

    const allQuestions = <QuestionSummary>[
      QuestionSummary(
        id: 'q-1',
        title: '相似三角形综合题',
        subject: '数学',
        stage: '初中',
        grade: '九年级上',
        textbook: '浙教版',
        chapter: '圆与相似',
        difficulty: 4,
        tags: ['相似', '几何综合'],
        stemPreview: r'已知 \triangle ABC \sim \triangle DEF，求证对应边比相等并求角度范围。',
      ),
      QuestionSummary(
        id: 'q-2',
        title: '函数图像与最值',
        subject: '数学',
        stage: '初中',
        grade: '九年级下',
        textbook: '人教版',
        chapter: '二次函数',
        difficulty: 3,
        tags: ['函数', '最值'],
        stemPreview: r'设抛物线 y=ax^2+bx+c 与 x 轴交于两点，讨论顶点坐标与最值。',
      ),
      QuestionSummary(
        id: 'q-3',
        title: '浮力实验与数据分析',
        subject: '物理',
        stage: '初中',
        grade: '八年级下',
        textbook: '通用版',
        chapter: '压强与浮力',
        difficulty: 2,
        tags: ['实验题', '浮力'],
        stemPreview: r'根据实验记录表分析排开液体体积与浮力大小的关系。',
      ),
    ];

    return allQuestions.where((question) {
      final matchesSubject =
          filters.subject == '全部学科' || question.subject == filters.subject;
      final matchesStage =
          filters.stage == '全部学段' || question.stage == filters.stage;
      final matchesTextbook =
          filters.textbook == '全部教材' || question.textbook == filters.textbook;
      final normalizedQuery = filters.query.trim().toLowerCase();
      final matchesQuery = normalizedQuery.isEmpty ||
          question.title.toLowerCase().contains(normalizedQuery) ||
          question.chapter.toLowerCase().contains(normalizedQuery) ||
          question.tags.any((tag) => tag.toLowerCase().contains(normalizedQuery));
      return matchesSubject && matchesStage && matchesTextbook && matchesQuery;
    }).toList();
  }

  Future<List<QuestionSummary>> listBasketQuestions() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final questions = await listQuestions();
    return questions.take(2).toList();
  }

  Future<List<DocumentSummary>> listDocuments() async {
    await Future<void>.delayed(const Duration(milliseconds: 220));

    return List<DocumentSummary>.from(_documents);
  }

  Future<DocumentSummary> createDocument({
    required String name,
    required String kind,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final document = DocumentSummary(
      id: 'doc-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      kind: kind,
      questionCount: 0,
      layoutCount: 0,
      latestExportStatus: 'not_started',
    );
    _documents.insert(0, document);
    _documentItems[document.id] = <DocumentItemSummary>[];
    return document;
  }

  Future<DocumentSummary?> getDocument(String documentId) async {
    final documents = await listDocuments();
    for (final document in documents) {
      if (document.id == documentId) {
        return document;
      }
    }
    return null;
  }

  Future<List<DocumentItemSummary>> listDocumentItems(String documentId) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return List<DocumentItemSummary>.from(
      _documentItems[documentId] ?? const <DocumentItemSummary>[],
    );
  }

  Future<void> addQuestionToDocument({
    required String documentId,
    required QuestionSummary question,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final items = _documentItems.putIfAbsent(
      documentId,
      () => <DocumentItemSummary>[],
    );
    items.add(
      DocumentItemSummary(
        id: '$documentId-item-${DateTime.now().millisecondsSinceEpoch}',
        kind: 'question',
        title: question.title,
        detail: '新增题目 · ${question.chapter}',
      ),
    );
  }

  Future<List<LayoutElementSummary>> listLayoutElements() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return List<LayoutElementSummary>.from(_layoutElements);
  }

  Future<void> addLayoutElementToDocument({
    required String documentId,
    required LayoutElementSummary layoutElement,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final items = _documentItems.putIfAbsent(
      documentId,
      () => <DocumentItemSummary>[],
    );
    items.add(
      DocumentItemSummary(
        id: '$documentId-item-${DateTime.now().millisecondsSinceEpoch}',
        kind: 'layout',
        title: layoutElement.name,
        detail: layoutElement.description,
      ),
    );
  }

  Future<void> moveDocumentItem({
    required String documentId,
    required String itemId,
    required int offset,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));

    final items = _documentItems[documentId];
    if (items == null) {
      return;
    }

    final index = items.indexWhere((item) => item.id == itemId);
    if (index < 0) {
      return;
    }

    final nextIndex = index + offset;
    if (nextIndex < 0 || nextIndex >= items.length) {
      return;
    }

    final item = items.removeAt(index);
    items.insert(nextIndex, item);
  }

  Future<void> removeDocumentItem({
    required String documentId,
    required String itemId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));

    final items = _documentItems[documentId];
    if (items == null) {
      return;
    }

    items.removeWhere((item) => item.id == itemId);
  }

  Future<void> createExportJob({
    required String documentId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final document = await getDocument(documentId);
    if (document == null) {
      return;
    }

    _exportJobs.insert(
      0,
      ExportJobSummary(
        id: 'job-${DateTime.now().millisecondsSinceEpoch}',
        documentName: document.name,
        format: 'pdf',
        status: 'pending',
        updatedAtLabel: '刚刚',
      ),
    );
  }

  Future<List<ExportJobSummary>> listExportJobs() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));

    return List<ExportJobSummary>.from(_exportJobs);
  }
}
