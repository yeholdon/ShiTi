import '../config/app_config.dart';
import '../models/auth_session.dart';
import '../models/document_item_summary.dart';
import '../models/export_job_summary.dart';
import '../models/document_summary.dart';
import '../models/library_filter_state.dart';
import '../models/layout_element_summary.dart';
import '../models/question_detail.dart';
import '../models/question_summary.dart';
import '../models/tenant_summary.dart';
import '../models/tenant_member_audit_event.dart';
import '../models/tenant_member_summary.dart';

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
      latestExportJobId: 'job-1',
      previewBlocks: [
        {
          'type': 'text',
          'text': '围绕相似三角形判定、比例转化和课堂追问编排的讲义。',
          'children': [
            {'type': 'latex', 'text': r'\frac{AB}{DE}=\frac{BC}{EF}'},
          ],
        },
      ],
    ),
    const DocumentSummary(
      id: 'doc-2',
      name: '二次函数周测卷',
      kind: 'paper',
      questionCount: 12,
      layoutCount: 0,
      latestExportStatus: 'pending',
      latestExportJobId: 'job-2',
      previewBlocks: [
        {
          'type': 'text',
          'text': '覆盖函数图像、最值与综合应用的周测试卷。',
        },
      ],
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
        previewBlocks: [
          {
            'type': 'text',
            'text': '请先回顾上节课的相似判定，再带着问题进入本节内容。',
          },
        ],
      ),
      const DocumentItemSummary(
        id: 'doc1-item-2',
        kind: 'question',
        title: '相似三角形综合题',
        detail: '例题 1 · 几何综合',
        previewBlocks: [
          {
            'type': 'text',
            'text': r'已知 \triangle ABC \sim \triangle DEF。',
            'children': [
              {
                'type': 'latex',
                'text': r'\frac{AB}{DE}=\frac{BC}{EF}',
              },
            ],
          },
        ],
      ),
      const DocumentItemSummary(
        id: 'doc1-item-3',
        kind: 'layout',
        title: '课堂提问框',
        detail: '板书与留白区域',
        previewBlocks: [
          {
            'type': 'text',
            'text': '请学生说明为什么先找对应角，再判断比例关系。',
          },
        ],
      ),
    ],
    'doc-2': <DocumentItemSummary>[
      const DocumentItemSummary(
        id: 'doc2-item-1',
        kind: 'question',
        title: '函数图像与最值',
        detail: '第 1 题 · 二次函数',
        previewBlocks: [
          {
            'type': 'text',
            'text': r'设抛物线 y=ax^2+bx+c 与 x 轴交于两点。',
          },
        ],
      ),
      const DocumentItemSummary(
        id: 'doc2-item-2',
        kind: 'question',
        title: '相似三角形综合题',
        detail: '第 2 题 · 几何综合',
        previewBlocks: [
          {
            'type': 'text',
            'text': r'求证对应边比相等，并进一步判断相关角的数量关系。',
          },
        ],
      ),
    ],
  };

  static final List<ExportJobSummary> _exportJobs = <ExportJobSummary>[
    const ExportJobSummary(
      id: 'job-1',
      documentId: 'doc-1',
      documentName: '九上相似专题讲义',
      format: 'pdf',
      status: 'succeeded',
      updatedAtLabel: '刚刚',
    ),
    const ExportJobSummary(
      id: 'job-2',
      documentId: 'doc-2',
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
      previewBlocks: [
        {
          'type': 'text',
          'text': '学习目标：理解相似三角形的判定与常见结论。',
        },
      ],
    ),
    LayoutElementSummary(
      id: 'layout-2',
      name: '课堂提问框',
      description: '用于放置板书提示、提问留白和互动任务。',
      previewBlocks: [
        {
          'type': 'text',
          'text': '请用一句话说出本题先找对应角还是先找边比？',
        },
      ],
    ),
    LayoutElementSummary(
      id: 'layout-3',
      name: '课后总结区',
      description: '用于讲义结尾总结和延伸作业提醒。',
      previewBlocks: [
        {
          'type': 'text',
          'text': '课后整理：相似三角形中最常用的三个比例转化。',
        },
      ],
    ),
  ];
  static final Set<String> _basketQuestionIds = <String>{'q-1', 'q-2'};
  static final Map<String, List<TenantMemberSummary>> _tenantMembers =
      <String, List<TenantMemberSummary>>{
    'math-studio': <TenantMemberSummary>[
      const TenantMemberSummary(
        id: 'member-1',
        userId: 'user-1',
        username: 'owner_teacher',
        role: 'owner',
        status: 'active',
        createdAtLabel: '今天',
      ),
      const TenantMemberSummary(
        id: 'member-2',
        userId: 'user-2',
        username: 'geometry_admin',
        role: 'admin',
        status: 'active',
        createdAtLabel: '昨天',
      ),
      const TenantMemberSummary(
        id: 'member-3',
        userId: 'user-3',
        username: 'new_member',
        role: 'member',
        status: 'active',
        createdAtLabel: '2 天前',
      ),
    ],
    'junior-physics': <TenantMemberSummary>[
      const TenantMemberSummary(
        id: 'member-4',
        userId: 'user-4',
        username: 'physics_owner',
        role: 'owner',
        status: 'active',
        createdAtLabel: '今天',
      ),
      const TenantMemberSummary(
        id: 'member-5',
        userId: 'user-5',
        username: 'lab_admin',
        role: 'admin',
        status: 'active',
        createdAtLabel: '昨天',
      ),
    ],
    'exam-lab': <TenantMemberSummary>[
      const TenantMemberSummary(
        id: 'member-6',
        userId: 'user-6',
        username: 'exam_owner',
        role: 'owner',
        status: 'active',
        createdAtLabel: '今天',
      ),
      const TenantMemberSummary(
        id: 'member-7',
        userId: 'user-7',
        username: 'exam_member',
        role: 'member',
        status: 'active',
        createdAtLabel: '昨天',
      ),
    ],
  };
  static final Map<String, List<TenantMemberAuditEvent>> _tenantMemberAuditEvents =
      <String, List<TenantMemberAuditEvent>>{};

  void _recordTenantMemberAuditEvent({
    required String tenantCode,
    required String userId,
    required String action,
    required String targetType,
    required String detail,
  }) {
    final key = '$tenantCode:$userId';
    final events = _tenantMemberAuditEvents[key] ?? const <TenantMemberAuditEvent>[];
    _tenantMemberAuditEvents[key] = <TenantMemberAuditEvent>[
      TenantMemberAuditEvent(
        id: 'audit-${DateTime.now().microsecondsSinceEpoch}',
        atLabel: DateTime.now().toIso8601String(),
        action: action,
        targetType: targetType,
        detail: detail,
      ),
      ...events,
    ].take(6).toList();
  }

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
    _tenantMembers[tenant.code] = <TenantMemberSummary>[
      const TenantMemberSummary(
        id: 'local-owner',
        userId: 'demo-user',
        username: 'demo_teacher',
        role: 'owner',
        status: 'active',
        createdAtLabel: '刚刚',
      ),
    ];
    return tenant;
  }

  Future<List<TenantMemberSummary>> listTenantMembers({
    required String tenantCode,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return List<TenantMemberSummary>.from(_tenantMembers[tenantCode] ?? const <TenantMemberSummary>[]);
  }

  Future<TenantMemberSummary> updateTenantMemberRole({
    required String tenantCode,
    required String memberId,
    required String role,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final members = _tenantMembers[tenantCode] ?? const <TenantMemberSummary>[];
    final index = members.indexWhere((member) => member.id == memberId);
    if (index < 0) {
      throw StateError('Tenant member not found');
    }
    final updated = members[index].copyWith(role: role);
    _tenantMembers[tenantCode] = <TenantMemberSummary>[
      ...members.take(index),
      updated,
      ...members.skip(index + 1),
    ];
    _recordTenantMemberAuditEvent(
      tenantCode: tenantCode,
      userId: updated.userId,
      action: 'tenant_member.role_updated',
      targetType: 'tenant_member',
      detail: '${members[index].role} -> ${updated.role}',
    );
    return updated;
  }

  Future<TenantMemberSummary> addTenantMember({
    required String tenantCode,
    required String username,
    required String role,
    String status = 'active',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty) {
      throw StateError('用户名不能为空');
    }

    final members = _tenantMembers[tenantCode] ?? const <TenantMemberSummary>[];
    final index = members.indexWhere((member) => member.username == normalizedUsername);
    final memberId = index >= 0
        ? members[index].id
        : 'member-${DateTime.now().microsecondsSinceEpoch}';
    final userId = index >= 0
        ? members[index].userId
        : 'user-${DateTime.now().microsecondsSinceEpoch}';
    final added = TenantMemberSummary(
      id: memberId,
      userId: userId,
      username: normalizedUsername,
      role: role,
      status: status,
      createdAtLabel: status == 'invited' ? '刚刚邀请' : '刚刚加入',
      updatedAtIso: DateTime.now().toIso8601String(),
      invitationExpiresAtIso: status == 'invited'
          ? DateTime.now().add(const Duration(days: 7)).toIso8601String()
          : null,
    );

    _tenantMembers[tenantCode] = <TenantMemberSummary>[
      added,
      ...members.where((member) => member.id != memberId),
    ];
    _recordTenantMemberAuditEvent(
      tenantCode: tenantCode,
      userId: added.userId,
      action: status == 'invited' ? 'tenant_member.invited' : 'tenant_member.added',
      targetType: 'tenant_member',
      detail: status == 'invited' ? 'invited as $role' : 'added as $role',
    );
    return added;
  }

  Future<TenantMemberSummary> updateTenantMemberStatus({
    required String tenantCode,
    required String memberId,
    required String status,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final members = _tenantMembers[tenantCode] ?? const <TenantMemberSummary>[];
    final index = members.indexWhere((member) => member.id == memberId);
    if (index < 0) {
      throw StateError('Tenant member not found');
    }
    final updated = members[index].copyWith(status: status);
    _tenantMembers[tenantCode] = <TenantMemberSummary>[
      ...members.take(index),
      updated,
      ...members.skip(index + 1),
    ];
    _recordTenantMemberAuditEvent(
      tenantCode: tenantCode,
      userId: updated.userId,
      action: 'tenant_member.status_updated',
      targetType: 'tenant_member',
      detail: '${members[index].status} -> ${updated.status}',
    );
    return updated;
  }

  Future<TenantMemberSummary> resendTenantMemberInvite({
    required String tenantCode,
    required String memberId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final members = _tenantMembers[tenantCode] ?? const <TenantMemberSummary>[];
    final index = members.indexWhere((member) => member.id == memberId);
    if (index < 0) {
      throw StateError('Tenant member not found');
    }
    final member = members[index];
    if (member.status != 'invited') {
      throw StateError('Only invited tenant members can be resent invitations');
    }
    final resent = member.copyWith(
      createdAtLabel: '刚刚邀请',
      updatedAtIso: DateTime.now().toIso8601String(),
      invitationExpiresAtIso: DateTime.now().add(const Duration(days: 7)).toIso8601String(),
    );
    _tenantMembers[tenantCode] = <TenantMemberSummary>[
      ...members.take(index),
      resent,
      ...members.skip(index + 1),
    ];
    _recordTenantMemberAuditEvent(
      tenantCode: tenantCode,
      userId: member.userId,
      action: 'tenant_member.invitation_resent',
      targetType: 'tenant_member',
      detail: 'invitation resent for ${member.username}',
    );
    return resent;
  }

  Future<void> removeTenantMember({
    required String tenantCode,
    required String memberId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final members = _tenantMembers[tenantCode] ?? const <TenantMemberSummary>[];
    final targetIndex = members.indexWhere((member) => member.id == memberId);
    final target = targetIndex >= 0 ? members[targetIndex] : null;
    _tenantMembers[tenantCode] = members.where((member) => member.id != memberId).toList();
    if (target != null) {
      _recordTenantMemberAuditEvent(
        tenantCode: tenantCode,
        userId: target.userId,
        action: 'tenant_member.removed',
        targetType: 'tenant_member',
        detail: 'removed from tenant',
      );
    }
  }

  Future<List<TenantMemberAuditEvent>> listTenantMemberAuditEvents({
    required String tenantCode,
    required String userId,
    int limit = 5,
  }) async {
    final events = _tenantMemberAuditEvents['$tenantCode:$userId'] ?? const <TenantMemberAuditEvent>[];
    return events.take(limit).toList();
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
    return questions
        .where((question) => _basketQuestionIds.contains(question.id))
        .toList();
  }

  Future<void> addQuestionToBasket(String questionId) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    _basketQuestionIds.add(questionId);
  }

  Future<void> removeQuestionFromBasket(String questionId) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    _basketQuestionIds.remove(questionId);
  }

  Future<void> clearBasket() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    _basketQuestionIds.clear();
  }

  Future<QuestionDetail?> getQuestionDetail(String questionId) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));

    const details = <String, QuestionDetail>{
      'q-1': QuestionDetail(
        id: 'q-1',
        title: '相似三角形综合题',
        subject: '数学',
        stage: '初中',
        grade: '九年级上',
        textbook: '浙教版',
        chapter: '圆与相似',
        difficulty: 4,
        tags: ['相似', '几何综合'],
        stemBlocks: [
          {
            'type': 'text',
            'text': r'已知 \triangle ABC \sim \triangle DEF。',
            'children': [
              {
                'type': 'latex',
                'text': r'\frac{AB}{DE}=\frac{BC}{EF}=\frac{AC}{DF}',
              },
            ],
          },
          {
            'type': 'text',
            'text': '求证对应边比相等，并进一步判断相关角的数量关系。',
            'children': [
              {
                'type': 'text',
                'text': '提示：先从对应角相等入手，再把角度关系转化成比例关系。',
              },
            ],
          },
          {'type': 'image', 'assetId': 'demo-geo-figure'}
        ],
        analysisBlocks: [
          {
            'type': 'text',
            'text': '先识别相似条件，再从对应角与对应边切入。',
            'children': [
              {
                'type': 'text',
                'text': '如果题干给出圆或角平分线，再检查是否可以补充辅助结论。',
              },
            ],
          }
        ],
        solutionBlocks: [
          {'type': 'text', 'text': '由已知可得两三角形对应角相等、对应边成比例。'},
          {
            'type': 'text',
            'text': '再结合角平分线或圆周角性质，可把结论逐步转化为边比和角度关系。',
            'blocks': [
              {
                'type': 'latex',
                'text': r'\angle A=\angle D,\ \angle B=\angle E',
              },
            ],
          }
        ],
        commentaryBlocks: [
          {'type': 'text', 'text': '适合放在九上几何综合专题讲义中。'}
        ],
        stemText: r'已知 \triangle ABC \sim \triangle DEF，求证对应边比相等，并进一步判断相关角的数量关系。',
        analysisText: '先识别相似条件，再从对应角与对应边切入，最后把比例关系转成可计算的几何量。',
        solutionText: '由已知可得两三角形对应角相等、对应边成比例；再结合角平分线或圆周角性质，可把结论逐步转化为边比和角度关系。',
        commentaryText: '适合放在九上几何综合专题的讲义中，既能训练识图，也能训练比例转化。',
        sourceText: '2025-09 校本周练 · 相似三角形专题',
      ),
      'q-2': QuestionDetail(
        id: 'q-2',
        title: '函数图像与最值',
        subject: '数学',
        stage: '初中',
        grade: '九年级下',
        textbook: '人教版',
        chapter: '二次函数',
        difficulty: 3,
        tags: ['函数', '最值'],
        stemBlocks: [
          {'type': 'text', 'text': r'设抛物线 y=ax^2+bx+c 与 x 轴交于两点。'},
          {'type': 'text', 'text': '讨论顶点坐标与最值，并分析参数变化对图像的影响。'},
          {'type': 'table', 'label': '参数讨论表'}
        ],
        analysisBlocks: [
          {'type': 'text', 'text': '核心是把解析式、顶点式与图像特征统一起来看。'}
        ],
        solutionBlocks: [
          {'type': 'text', 'text': '将一般式配方得到顶点式。'},
          {'type': 'text', 'text': '利用对称轴和顶点纵坐标公式判断最值。'}
        ],
        commentaryBlocks: [
          {'type': 'text', 'text': '适合和图像性质、根与系数关系放在同一专题卷中。'}
        ],
        stemText: r'设抛物线 y=ax^2+bx+c 与 x 轴交于两点，讨论顶点坐标与最值，并分析参数变化对图像的影响。',
        analysisText: '核心是把函数解析式、顶点式与图像特征统一起来看，先抓开口方向，再抓对称轴和顶点。',
        solutionText: '将一般式配方得到顶点式，利用对称轴 x=-b/2a 和顶点纵坐标公式判断最值，再根据与 x 轴交点情况讨论参数范围。',
        commentaryText: '适合和图像性质、根与系数关系放在同一份专题卷中连续训练。',
        sourceText: '2025-03 九下阶段性复习 · 二次函数',
      ),
      'q-3': QuestionDetail(
        id: 'q-3',
        title: '浮力实验与数据分析',
        subject: '物理',
        stage: '初中',
        grade: '八年级下',
        textbook: '通用版',
        chapter: '压强与浮力',
        difficulty: 2,
        tags: ['实验题', '浮力'],
        stemBlocks: [
          {'type': 'text', 'text': '根据实验记录表分析排开液体体积与浮力大小的关系。'},
          {'type': 'table', 'label': '实验记录表'}
        ],
        analysisBlocks: [
          {'type': 'text', 'text': '先读实验变量，再看控制变量与因变量。'}
        ],
        solutionBlocks: [
          {'type': 'text', 'text': '比较不同组数据可知，排开液体体积越大，测得浮力越大。'},
          {'type': 'text', 'text': '若数据偏差明显，则从读数和液体残留分析误差。'}
        ],
        commentaryBlocks: [
          {'type': 'text', 'text': '适合实验探究讲义，配合表格与结论归纳框。'}
        ],
        stemText: r'根据实验记录表分析排开液体体积与浮力大小的关系，并说明误差可能来源。',
        analysisText: '这类题先读实验变量，再看控制变量与因变量，最后用数据趋势支撑结论。',
        solutionText: '比较不同组数据可知，排开液体体积越大，测得浮力越大；若数据偏差明显，则要从弹簧测力计读数、液体残留等角度分析误差。',
        commentaryText: '可直接作为实验探究题模板，适合讲义中配套表格与结论归纳框。',
        sourceText: '2024-11 实验探究训练 · 浮力',
      ),
    };

    return details[questionId];
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
      previewBlocks: [
        {
          'type': 'text',
          'text': '${kind == 'paper' ? '试卷' : '讲义'}已创建，接下来可以加入题目或排版元素。',
        },
      ],
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

  Future<DocumentItemSummary> addQuestionToDocument({
    required String documentId,
    required QuestionSummary question,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final items = _documentItems.putIfAbsent(
      documentId,
      () => <DocumentItemSummary>[],
    );
    final item = DocumentItemSummary(
      id: '$documentId-item-${DateTime.now().millisecondsSinceEpoch}',
      kind: 'question',
      title: question.title,
      detail: '新增题目 · ${question.chapter}',
      previewBlocks: [
        {
          'type': 'text',
          'text': question.stemPreview,
        },
      ],
    );
    items.add(item);
    _syncDocumentCounts(documentId);
    return item;
  }

  Future<List<DocumentItemSummary>> addQuestionsToDocument({
    required String documentId,
    required List<QuestionSummary> questions,
  }) async {
    final items = <DocumentItemSummary>[];
    for (final question in questions) {
      items.add(
        await addQuestionToDocument(
          documentId: documentId,
          question: question,
        ),
      );
    }
    return items;
  }

  Future<List<LayoutElementSummary>> listLayoutElements() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return List<LayoutElementSummary>.from(_layoutElements);
  }

  Future<DocumentItemSummary> addLayoutElementToDocument({
    required String documentId,
    required LayoutElementSummary layoutElement,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final items = _documentItems.putIfAbsent(
      documentId,
      () => <DocumentItemSummary>[],
    );
    final item = DocumentItemSummary(
      id: '$documentId-item-${DateTime.now().millisecondsSinceEpoch}',
      kind: 'layout',
      title: layoutElement.name,
      detail: layoutElement.description,
      previewBlocks: [
        {
          'type': 'text',
          'text': layoutElement.description,
        },
      ],
    );
    items.add(item);
    _syncDocumentCounts(documentId);
    return item;
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
    _syncDocumentCounts(documentId);
  }

  void _syncDocumentCounts(String documentId) {
    final documentIndex = _documents.indexWhere((item) => item.id == documentId);
    if (documentIndex < 0) {
      return;
    }

    final document = _documents[documentIndex];
    final items = _documentItems[documentId] ?? const <DocumentItemSummary>[];
    final questionCount = items.where((item) => item.kind == 'question').length;
    final layoutCount = items.where((item) => item.kind == 'layout').length;

    _documents[documentIndex] = DocumentSummary(
      id: document.id,
      name: document.name,
      kind: document.kind,
      questionCount: questionCount,
      layoutCount: layoutCount,
      latestExportStatus: document.latestExportStatus,
      latestExportJobId: document.latestExportJobId,
      previewBlocks: _buildDocumentPreviewBlocks(documentId, document),
    );
  }

  List<Map<String, dynamic>> _buildDocumentPreviewBlocks(
    String documentId,
    DocumentSummary document,
  ) {
    final items = _documentItems[documentId] ?? const <DocumentItemSummary>[];
    if (items.isNotEmpty) {
      final firstItem = items.first;
      if (firstItem.previewBlocks.isNotEmpty) {
        return firstItem.previewBlocks;
      }
      if (firstItem.detail.trim().isNotEmpty) {
        return <Map<String, dynamic>>[
          <String, dynamic>{'type': 'text', 'text': firstItem.detail},
        ];
      }
    }

    return <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'text',
        'text':
            '${document.kind == 'paper' ? '试卷' : '讲义'} · 题目 ${document.questionCount} · 排版 ${document.layoutCount}',
      },
    ];
  }

  Future<ExportJobSummary> createExportJob({
    required String documentId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final document = await getDocument(documentId);
    if (document == null) {
      return const ExportJobSummary(
        id: '',
        documentId: null,
        documentName: '未知文档',
        format: 'pdf',
        status: 'failed',
        updatedAtLabel: '刚刚',
      );
    }

    final documentIndex = _documents.indexWhere((item) => item.id == documentId);
    if (documentIndex >= 0) {
      final current = _documents[documentIndex];
      _documents[documentIndex] = DocumentSummary(
        id: current.id,
        name: current.name,
        kind: current.kind,
        questionCount: current.questionCount,
        layoutCount: current.layoutCount,
        latestExportStatus: 'pending',
        latestExportJobId: current.latestExportJobId,
        previewBlocks: current.previewBlocks,
      );
    }

    final job = ExportJobSummary(
      id: 'job-${DateTime.now().millisecondsSinceEpoch}',
      documentId: document.id,
      documentName: document.name,
      format: 'pdf',
      status: 'pending',
      updatedAtLabel: '刚刚',
    );
    _exportJobs.insert(0, job);

    if (documentIndex >= 0) {
      final current = _documents[documentIndex];
      _documents[documentIndex] = DocumentSummary(
        id: current.id,
        name: current.name,
        kind: current.kind,
        questionCount: current.questionCount,
        layoutCount: current.layoutCount,
        latestExportStatus: 'pending',
        latestExportJobId: job.id,
        previewBlocks: current.previewBlocks,
      );
    }

    return job;
  }

  Future<ExportJobSummary> retryExportJob({
    required String jobId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));

    final jobIndex = _exportJobs.indexWhere((item) => item.id == jobId);
    if (jobIndex < 0) {
      return const ExportJobSummary(
        id: '',
        documentName: '未命名文档',
        format: 'pdf',
        status: 'failed',
        updatedAtLabel: '刚刚',
      );
    }

    final current = _exportJobs[jobIndex];
    final next = ExportJobSummary(
      id: current.id,
      documentId: current.documentId,
      documentName: current.documentName,
      format: current.format,
      status: 'pending',
      updatedAtLabel: '刚刚',
    );
    _exportJobs[jobIndex] = next;

    final documentId = current.documentId;
    if (documentId != null && documentId.isNotEmpty) {
      final documentIndex = _documents.indexWhere((item) => item.id == documentId);
      if (documentIndex >= 0) {
        final document = _documents[documentIndex];
        _documents[documentIndex] = DocumentSummary(
          id: document.id,
          name: document.name,
          kind: document.kind,
          questionCount: document.questionCount,
          layoutCount: document.layoutCount,
          latestExportStatus: 'pending',
          latestExportJobId: current.id,
          previewBlocks: document.previewBlocks,
        );
      }
    }

    return next;
  }

  Future<List<ExportJobSummary>> listExportJobs() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));

    return List<ExportJobSummary>.from(_exportJobs);
  }
}
