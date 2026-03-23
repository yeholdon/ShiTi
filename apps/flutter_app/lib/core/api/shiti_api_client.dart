import '../config/app_config.dart';
import '../models/auth_session.dart';
import '../models/document_item_summary.dart';
import '../models/export_job_summary.dart';
import '../models/document_summary.dart';
import '../models/library_filter_state.dart';
import '../models/layout_element_summary.dart';
import '../models/password_reset_request_result.dart';
import '../models/question_detail.dart';
import '../models/question_summary.dart';
import '../models/tenant_summary.dart';
import '../models/tenant_member_audit_event.dart';
import '../models/tenant_member_summary.dart';
import '../network/http_json_client.dart';

class ShiTiApiClient {
  const ShiTiApiClient();

  static final Map<String, String> _localPasswords = <String, String>{
    'teacher_demo': 'demo-password',
  };
  static final Map<String, String> _localResetTokens = <String, String>{};

  static final List<TenantSummary> _tenants = <TenantSummary>[
    const TenantSummary(
      id: 'tenant-personal',
      code: 'my-space',
      name: '我的个人工作区',
      role: 'owner',
      kind: 'personal',
    ),
    const TenantSummary(
      id: 'tenant-1',
      code: 'math-studio',
      name: '数学教研组',
      role: 'owner',
      kind: 'organization',
    ),
    const TenantSummary(
      id: 'tenant-2',
      code: 'junior-physics',
      name: '初中理化题库',
      role: 'admin',
      kind: 'organization',
    ),
    const TenantSummary(
      id: 'tenant-3',
      code: 'exam-lab',
      name: '中考冲刺专题库',
      role: 'member',
      kind: 'organization',
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
        sourceLayoutElementId: 'layout-1',
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
        subject: '数学',
        stage: '初中',
        grade: '九年级',
        textbook: '浙教版九上',
        chapter: '相似三角形',
        sourceQuestionId: 'q-1',
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
        sourceLayoutElementId: 'layout-2',
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
        subject: '数学',
        stage: '初中',
        grade: '九年级',
        textbook: '浙教版九上',
        chapter: '二次函数',
        sourceQuestionId: 'q-2',
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
        subject: '数学',
        stage: '初中',
        grade: '九年级',
        textbook: '浙教版九上',
        chapter: '相似三角形',
        sourceQuestionId: 'q-1',
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

  static final List<LayoutElementSummary> _layoutElements =
      <LayoutElementSummary>[
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
  static final Map<String, List<TenantMemberAuditEvent>>
      _tenantMemberAuditEvents = <String, List<TenantMemberAuditEvent>>{};

  void _recordTenantMemberAuditEvent({
    required String tenantCode,
    required String userId,
    required String action,
    required String targetType,
    required String detail,
  }) {
    final key = '$tenantCode:$userId';
    final events =
        _tenantMemberAuditEvents[key] ?? const <TenantMemberAuditEvent>[];
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
    final normalizedUsername =
        username.trim().isEmpty ? 'demo_teacher' : username.trim();
    final storedPassword = _localPasswords[normalizedUsername];
    if (storedPassword != null && storedPassword != password) {
      throw const HttpJsonException(
        statusCode: 401,
        message: 'Invalid password',
      );
    }

    return AuthSession(
      userId: 'demo-user',
      username: normalizedUsername,
      accessLevel: 'member',
      accessToken: 'local-demo-token',
      tokenPreview: 'local-demo-token',
    );
  }

  Future<AuthSession> register({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    final existingPassword = _localPasswords[normalizedUsername];
    if (existingPassword != null && existingPassword != password) {
      throw const HttpJsonException(
        statusCode: 409,
        message: 'Username already exists',
      );
    }
    _localPasswords[normalizedUsername] = password;
    return login(username: username, password: password);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final existingPassword = _localPasswords['teacher_demo'];
    if (existingPassword != null && existingPassword != currentPassword) {
      throw const HttpJsonException(
        statusCode: 401,
        message: 'Invalid current password',
      );
    }
    _localPasswords['teacher_demo'] = newPassword;
  }

  Future<PasswordResetRequestResult> requestPasswordReset({
    required String username,
    String deliveryMode = 'preview',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final normalizedUsername = username.trim();
    if (!_localPasswords.containsKey(normalizedUsername)) {
      return PasswordResetRequestResult(
        deliveryMode: deliveryMode,
        deliveryTransport: deliveryMode == 'preview'
            ? 'inline'
            : deliveryMode == 'email'
                ? 'console'
                : 'console',
      );
    }
    final token = 'reset-${DateTime.now().millisecondsSinceEpoch}';
    _localResetTokens[normalizedUsername] = token;
    final previewHint = '...${token.substring(token.length - 6)}';
    return PasswordResetRequestResult(
      deliveryMode: deliveryMode,
      deliveryTransport: deliveryMode == 'preview' ? 'inline' : 'console',
      deliveryTargetHint: deliveryMode == 'preview'
          ? '当前页面'
          : deliveryMode == 'email'
              ? normalizedUsername
              : '服务器日志',
      requestId: 'local-$normalizedUsername',
      resetTokenPreview: deliveryMode == 'preview' ? token : null,
      previewHint: previewHint,
      cooldownSeconds: 60,
    );
  }

  Future<void> resetPassword({
    required String username,
    required String resetToken,
    required String newPassword,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final normalizedUsername = username.trim();
    if (_localResetTokens[normalizedUsername] != resetToken) {
      throw const HttpJsonException(
        statusCode: 401,
        message: 'Invalid or expired reset token',
      );
    }
    _localPasswords[normalizedUsername] = newPassword;
    _localResetTokens.remove(normalizedUsername);
  }

  Future<void> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
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
      kind: 'organization',
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
    return List<TenantMemberSummary>.from(
        _tenantMembers[tenantCode] ?? const <TenantMemberSummary>[]);
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
    final index =
        members.indexWhere((member) => member.username == normalizedUsername);
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
      action:
          status == 'invited' ? 'tenant_member.invited' : 'tenant_member.added',
      targetType: 'tenant_member',
      detail: status == 'invited' ? 'invited as $role' : 'added as $role',
    );
    return added;
  }

  Future<TenantMemberSummary> joinCurrentTenant({
    required String tenantCode,
    required String role,
    String status = 'active',
  }) async {
    final members = _tenantMembers[tenantCode] ?? const <TenantMemberSummary>[];
    final owner = members.cast<TenantMemberSummary?>().firstWhere(
          (member) => member?.role == role && member?.status == status,
          orElse: () => null,
        );
    if (owner != null) {
      return owner;
    }
    return addTenantMember(
      tenantCode: tenantCode,
      username: 'demo_teacher',
      role: role,
      status: status,
    );
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
      invitationExpiresAtIso:
          DateTime.now().add(const Duration(days: 7)).toIso8601String(),
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
    _tenantMembers[tenantCode] =
        members.where((member) => member.id != memberId).toList();
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
    final events = _tenantMemberAuditEvents['$tenantCode:$userId'] ??
        const <TenantMemberAuditEvent>[];
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
        previewBlocks: [
          {'type': 'text', 'text': r'已知 '},
          {'type': 'latex', 'text': r'\triangle ABC \sim \triangle DEF'},
          {'type': 'text', 'text': '，求证对应边比相等并求角度范围。'},
        ],
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
        previewBlocks: [
          {'type': 'text', 'text': '设抛物线 '},
          {'type': 'latex', 'text': r'y=ax^2+bx+c'},
          {'type': 'text', 'text': ' 与 x 轴交于两点，讨论顶点坐标与最值。'},
        ],
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
        previewBlocks: [
          {'type': 'text', 'text': '根据实验记录表分析排开液体体积与浮力大小的关系。'},
          {
            'type': 'table',
            'label': '实验记录表预览',
            'rows': [
              ['组别', '排开体积', '浮力'],
              ['1', '20 mL', '0.2 N'],
              ['2', '40 mL', '0.4 N'],
            ],
          },
        ],
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
          question.tags
              .any((tag) => tag.toLowerCase().contains(normalizedQuery));
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
          {
            'type': 'image',
            'assetId': 'demo-geo-figure',
            'src':
                'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="960" height="540" viewBox="0 0 960 540"><rect width="960" height="540" fill="%23EAF4FD"/><path d="M160 400 L360 160 L620 380 L790 120" stroke="%233390EC" stroke-width="12" fill="none"/><circle cx="160" cy="400" r="10" fill="%232B79C2"/><circle cx="360" cy="160" r="10" fill="%232B79C2"/><circle cx="620" cy="380" r="10" fill="%232B79C2"/><circle cx="790" cy="120" r="10" fill="%232B79C2"/><text x="130" y="430" font-size="28" fill="%2343576A">A</text><text x="330" y="150" font-size="28" fill="%2343576A">B</text><text x="630" y="410" font-size="28" fill="%2343576A">C</text><text x="800" y="110" font-size="28" fill="%2343576A">D</text></svg>',
            'label': '几何示意图',
            'caption': 'AB 与 DE、BC 与 EF、AC 与 DF 为对应边。',
            'width': 960,
            'height': 540,
          }
        ],
        analysisBlocks: [
          {
            'type': 'heading',
            'level': 2,
            'text': '分析路径',
          },
          {
            'type': 'step',
            'index': 1,
            'label': '锁定对应角',
            'text': '先从相似三角形中找出对应角，再判断已知角与未知角的关系。',
          },
          {
            'type': 'text',
            'text': '先识别相似条件，再从对应角与对应边切入。',
            'children': [
              {
                'type': 'text',
                'text': '如果题干给出圆或角平分线，再检查是否可以补充辅助结论。',
              },
            ],
          },
          {
            'type': 'callout',
            'label': '解题提醒',
            'text': '先找对应角，再写对应边比例，最后再处理角度范围。',
          },
          {
            'type': 'divider',
          },
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
        referenceAnswerBlocks: [
          {
            'type': 'latex',
            'text': r'\frac{AB}{DE}=\frac{BC}{EF}=\frac{AC}{DF}',
          },
          {
            'type': 'text',
            'text': '结合对应角相等与相似性质，可继续推出角度之间的数量关系。',
          },
        ],
        scoringPointBlocks: [
          {'type': 'text', 'text': '评分点（4 分）：说明对应角相等。'},
          {'type': 'text', 'text': '评分点（6 分）：完整写出对应边成比例并得出结论。'},
          {
            'type': 'rubric',
            'title': '评分标准',
            'rubric': [
              {
                'label': '对应关系判断',
                'score': '4 分',
                'text': '能准确说明对应角相等，并指出对应边关系。',
              },
              {
                'label': '比例式书写',
                'score': '3 分',
                'text': '比例顺序正确，书写完整。',
              },
              {
                'label': '结论转化',
                'score': '3 分',
                'text': '能解释比例关系如何进一步转成角度或长度结论。',
              },
            ],
          },
        ],
        commentaryBlocks: [
          {'type': 'text', 'text': '适合放在九上几何综合专题讲义中。'},
          {
            'type': 'quote',
            'label': '教研备注',
            'text': '这一题更适合先让学生口头说出对应关系，再要求写完整比例式。',
          },
          {
            'type': 'list',
            'label': '课堂推进建议',
            'ordered': true,
            'items': [
              {'text': '先独立标注对应边与对应角。'},
              {'text': '再小组讨论比例关系如何转成角度结论。'},
            ],
          },
          {
            'type': 'code',
            'label': '板书结构建议',
            'language': 'plain',
            'code': '1. 标对应角\\n2. 写对应边比例\\n3. 推角度范围',
          },
          {
            'type': 'video',
            'label': '教师讲解片段',
            'mediaUrl': 'https://example.com/lesson/similar-triangles',
            'caption': '用于课后回看相似三角形对应关系的口头讲解。',
          },
        ],
        sourceBlocks: [
          {'type': 'text', 'text': '2025-09 校本周练'},
          {'type': 'text', 'text': '相似三角形专题'},
          {
            'type': 'checklist',
            'label': '使用前检查',
            'checklist': [
              {'text': '确认学生已掌握相似判定', 'checked': true},
              {'text': '准备对应边比例的板书模板', 'checked': false},
            ],
          },
          {
            'type': 'columns',
            'label': '资料概览',
            'columns': [
              {
                'label': '来源',
                'text': '校本教研',
              },
              {
                'label': '适用场景',
                'text': '课堂讲评 / 讲义编排',
              },
            ],
          },
          {
            'type': 'link',
            'label': '教研资料',
            'href': 'https://example.com/research/similar-triangles',
            'description': '对应角与对应边的课堂讲解材料。',
          },
          {
            'type': 'qa',
            'title': '教研问答',
            'faq': [
              {
                'question': '为什么要先判定相似再求长度？',
                'answer': [
                  {
                    'type': 'text',
                    'text': '先固定对应关系，后续比例式和角度转化才不会错配边。',
                  },
                ],
              },
              {
                'question': '课堂上最容易错在哪里？',
                'answer': [
                  {
                    'type': 'text',
                    'text': '学生常把对应角判断对了，但在对应边书写顺序上出错。',
                  },
                ],
              },
            ],
          },
          {
            'type': 'timeline',
            'title': '课堂推进节奏',
            'events': [
              {
                'time': '导入 3 分钟',
                'title': '复盘相似判定',
                'text': '快速回顾对应角相等、对应边成比例这两个核心入口。',
              },
              {
                'time': '例题 8 分钟',
                'title': '建立对应关系',
                'content': [
                  {
                    'type': 'text',
                    'text': '先找对应角，再写比例式，避免学生直接套边比。',
                  },
                ],
              },
              {
                'time': '追问 4 分钟',
                'title': '比例如何转成角度结论',
                'text': '引导学生说明为什么结论不是直接算出，而是逐步转化得到。',
              },
            ],
          },
          {
            'type': 'stats',
            'title': '讲评指标',
            'stats': [
              {
                'label': '建议时长',
                'value': '15 分钟',
                'description': '适合作为相似专题例题讲评主线。',
              },
              {
                'label': '易错点',
                'value': '2 处',
                'description': '对应边顺序、比例式书写最常出错。',
              },
              {
                'label': '课堂追问',
                'value': '3 个',
                'description': '建议围绕对应关系与比例转化展开。',
              },
            ],
          },
          {
            'type': 'chart',
            'title': '班级表现分布',
            'series': [
              {
                'label': '对应边顺序正确',
                'value': 82,
                'description': '大多数学生能先说清对应关系再写比例。',
              },
              {
                'label': '比例式完整',
                'value': 64,
                'description': '部分学生仍会漏写对应边或顺序颠倒。',
              },
              {
                'label': '结论转化准确',
                'value': 47,
                'description': '从比例到角度/长度结论的过渡仍需追问。',
              },
            ],
          },
          {
            'type': 'matrix',
            'title': '课堂观察矩阵',
            'matrix': [
              {
                'label': '识图',
                'value': '高频失分',
                'content': [
                  {
                    'type': 'text',
                    'text': '主要看学生能否先说出对应角和对应边。',
                  },
                ],
              },
              {
                'label': '比例书写',
                'value': '重点追问',
                'content': [
                  {
                    'type': 'text',
                    'text': '要求学生解释比例顺序为什么不能写反。',
                  },
                ],
              },
              {
                'label': '讲评方式',
                'value': '先口述再板书',
              },
              {
                'label': '课后巩固',
                'value': '配 1 道变式',
              },
            ],
          },
          {
            'type': 'flow',
            'title': '讲评推进流程',
            'flow': [
              {
                'title': '先锁定对应关系',
                'text': '先让学生口头说清对应角和对应边，再开始写比例式。',
              },
              {
                'title': '统一比例模板',
                'text': '把对应边顺序固定下来，减少后续书写错误。',
              },
              {
                'title': '再过渡到角度结论',
                'text': '引导学生说明比例关系如何转成角度判断。',
              },
            ],
          },
          {
            'type': 'decision',
            'title': '课堂判断分支',
            'decision': [
              {
                'condition': '学生已找准对应边',
                'outcome': '直接进入比例书写与结论转化。',
              },
              {
                'condition': '学生仍反复写错顺序',
                'outcome': '先给统一板书模板，再要求口头解释顺序依据。',
              },
            ],
          },
          {
            'type': 'legend',
            'title': '图例说明',
            'legend': [
              {
                'marker': 'A',
                'label': '对应角',
                'text': '先用于锁定两个三角形之间的映射关系。',
              },
              {
                'marker': 'B',
                'label': '比例模板',
                'text': '板书时统一用来提示比例顺序。',
              },
            ],
          },
          {
            'type': 'pairs',
            'title': '资料属性',
            'pairs': [
              {
                'key': '适用阶段',
                'value': '九年级上学期几何复习',
              },
              {
                'key': '推荐形式',
                'value': '课堂讲评 + 讲义整理',
              },
              {
                'key': '课堂目标',
                'value': '稳定对应关系判断和比例书写顺序',
              },
            ],
          },
          {
            'type': 'schema',
            'title': '知识关系图',
            'schema': [
              {
                'title': '相似判定',
                'text': '先确认两个三角形满足角角或边边边比例条件。',
              },
              {
                'title': '对应关系',
                'text': '再锁定对应角与对应边，统一后续书写顺序。',
              },
              {
                'title': '比例转化',
                'text': '最后把比例关系转成角度或长度结论。',
              },
            ],
          },
          {
            'type': 'milestones',
            'title': '课堂关键节点',
            'milestones': [
              {
                'title': '对应关系说清',
                'status': '完成',
                'text': '先确认学生能口头说明对应角和对应边。',
              },
              {
                'title': '比例模板统一',
                'status': '进行中',
                'text': '全班统一比例顺序后，再进入推理环节。',
              },
              {
                'title': '结论转化',
                'status': '待推进',
                'text': '最后要求学生说明比例如何转到角度或长度结论。',
              },
            ],
          },
          {
            'type': 'badges',
            'title': '课堂标签',
            'badges': [
              '识图先行',
              '比例模板',
              '口头讲解',
              '几何追问',
            ],
          },
          {
            'type': 'references',
            'title': '参考资料',
            'references': [
              {
                'label': '校本教研手册',
                'text': '相似三角形专题讲评建议。',
                'href':
                    'https://example.com/research/similar-triangles-handbook',
              },
              {
                'label': '板书模板说明',
                'text': '对应边比例书写顺序统一规范。',
              },
            ],
          },
          {
            'type': 'highlights',
            'title': '重点批注',
            'highlights': [
              {
                'tag': '误区',
                'title': '对应边顺序',
                'text': '学生容易直接套比例，先让其口头说清对应关系再写式子。',
              },
              {
                'tag': '追问',
                'title': '比例到结论',
                'text': '要求学生说明为什么比例关系可以进一步推出角度或长度结论。',
              },
            ],
          },
          {
            'type': 'outline',
            'title': '讲评提纲',
            'outline': [
              {
                'title': '先复盘相似判定',
                'text': '快速确认学生对角角、边边边比例这两个入口的掌握。',
              },
              {
                'title': '再统一对应边顺序',
                'text': '要求全班先口头说明，再进入比例式书写。',
              },
              {
                'title': '最后转到结论生成',
                'text': '引导学生说明比例关系如何进一步推出角度或长度结论。',
              },
            ],
          },
          {
            'type': 'warnings',
            'title': '风险提醒',
            'warnings': [
              {
                'title': '不要直接套比例',
                'text': '若学生未先说清对应角与对应边，后续比例式很容易整组写反。',
              },
              {
                'title': '避免只给结论',
                'text': '讲评时要追问比例关系如何一步步转成角度或长度结论。',
              },
            ],
          },
          {
            'type': 'pitfalls',
            'title': '常见误区',
            'pitfalls': [
              {
                'title': '只背模板不看对应关系',
                'text': '学生容易把比例模板当成固定公式，忽略先确认对应角和对应边。',
              },
              {
                'title': '结论跳步过快',
                'text': '比例式刚写完就直接下长度结论，中间依据没有说清楚，后续容易失分。',
              },
            ],
          },
          {
            'type': 'glossary',
            'title': '术语表',
            'glossary': [
              {
                'term': '对应角',
                'definition': '两个相似三角形中位置相对一致的一组角，用来锁定后续对应边关系。',
              },
              {
                'term': '比例式',
                'definition': '把对应边按统一顺序写成相等的比，是后续推理的核心桥梁。',
              },
            ],
          },
          {
            'type': 'examples',
            'title': '示例列表',
            'examples': [
              {
                'title': '口头示例',
                'text': '先说出对应角，再让学生复述对应边顺序，最后再写比例式。',
              },
              {
                'title': '板书示例',
                'text': '把 AB/DE = AC/DF 固定成统一模板，避免顺序来回切换。',
              },
            ],
          },
          {
            'type': 'tips',
            'title': '提示建议',
            'tips': [
              {
                'title': '先让学生口述',
                'text': '在板书前先要求学生说出对应角和对应边，能明显降低顺序错误。',
              },
              {
                'title': '追问不要过快给答案',
                'text': '保留一步“为什么可以这样转化”的追问，能让结论更稳。',
              },
            ],
          },
          {
            'type': 'objectives',
            'title': '教学目标',
            'objectives': [
              {
                'title': '先说清对应关系',
                'text': '学生能够先用语言说明对应角与对应边，再进入比例式书写。',
              },
              {
                'title': '再完成比例转化',
                'text': '学生能够把比例关系稳定转成角度或长度结论，并说明每一步依据。',
              },
            ],
          },
          {
            'type': 'prerequisites',
            'title': '前置要求',
            'prerequisites': [
              {
                'title': '先会识别对应角',
                'text': '进入比例讲评前，学生需要能稳定指出两个相似三角形里的对应角。',
              },
              {
                'title': '先统一边的书写顺序',
                'text': '要求学生在写比例式前先约定对应边顺序，避免后续整组写反。',
              },
            ],
          },
          {
            'type': 'materials',
            'title': '资料清单',
            'materials': [
              {
                'title': '板书模板',
                'text': '准备一版固定的比例式书写模板，方便全班统一顺序。',
              },
              {
                'title': '对应关系示意图',
                'text': '准备一张标出对应角和对应边的示意图，便于讲评时快速指认。',
              },
            ],
          },
          {
            'type': 'constraints',
            'title': '约束规则',
            'constraints': [
              {
                'title': '先口述后板书',
                'text': '没有先口述对应关系前，不进入比例式板书，避免顺序直接写反。',
              },
              {
                'title': '一次只改一个变量',
                'text': '讲评同一轮中只允许替换一个条件，保证学生能看清每一步转化依据。',
              },
            ],
          },
          {
            'type': 'notes',
            'title': '补充说明',
            'notes': [
              {
                'title': '板书时先统一顺序',
                'text': '讲评过程中不要临时切换比例式顺序，否则学生会把对应关系和运算顺序混在一起。',
              },
              {
                'title': '口头确认后再下结论',
                'text': '如果学生还在犹豫对应边，先口头确认，再让其给出最终结论。',
              },
            ],
          },
          {
            'type': 'takeaways',
            'title': '结论提炼',
            'takeaways': [
              {
                'title': '先锁定对应关系',
                'text': '对应角和对应边一旦说清，后面的比例式和结论转换都会更稳定。',
              },
              {
                'title': '统一模板能显著降错',
                'text': '板书顺序固定后，学生更容易把注意力放在推理依据，而不是形式切换上。',
              },
            ],
          },
          {
            'type': 'activities',
            'title': '活动建议',
            'activities': [
              {
                'title': '先做对应关系口述',
                'text': '两人一组互相口述对应角和对应边，确认后再写比例式。',
              },
              {
                'title': '再做模板纠错',
                'text': '给出一组顺序写错的比例式，让学生说明错在哪里并重写。',
              },
            ],
          },
          {
            'type': 'strategies',
            'title': '策略方法',
            'strategies': [
              {
                'title': '先统一观察顺序',
                'text': '固定成“找对应角 -> 说对应边 -> 写比例式”的顺序，降低讲评时的切换成本。',
              },
              {
                'title': '把结论拆成两步',
                'text': '先确认比例关系成立，再单独说明如何从比例推出长度或角度结论。',
              },
            ],
          },
          {
            'type': 'checks',
            'title': '检查校验',
            'checks': [
              {
                'title': '先核对对应边顺序',
                'text': '比例式落笔前，先让学生口头确认两组三角形的对应边顺序是否一致。',
              },
              {
                'title': '再核对结论依据',
                'text': '长度或角度结论写出后，再追问其是由哪一步比例关系推出的。',
              },
            ],
          },
          {
            'type': 'heuristics',
            'title': '经验法则',
            'heuristics': [
              {
                'title': '先找最稳的对应角',
                'text': '一旦图形复杂，先从最明显的一组对应角入手，再向对应边扩展。',
              },
              {
                'title': '能口述就不急着板书',
                'text': '如果学生还说不清推理路径，先口述完整，再写比例和结论。',
              },
            ],
          },
          {
            'type': 'signals',
            'title': '观察信号',
            'signals': [
              {
                'title': '先说角再写边',
                'text': '如果学生能先准确说出对应角，再进入边的比例表达，通常说明对应关系已经稳定。',
              },
              {
                'title': '能补出中间依据',
                'text': '学生在结论前能主动补出比例到结论的中间依据，说明推理不是机械套模板。',
              },
            ],
          },
          {
            'type': 'evidence',
            'title': '依据与证明',
            'evidence': [
              {
                'title': '先锁定对应角',
                'text': '由两组对应角相等，先确认两个三角形具备相似判定所需的角条件。',
              },
              {
                'title': '再说明比例来源',
                'text': '比例式中的每一项都要能追溯到对应边，而不是只给出最终比值。',
              },
            ],
          },
          {
            'type': 'counterexamples',
            'title': '反例与非例',
            'counterexamples': [
              {
                'title': '只看边长比不够',
                'text': '如果没有先确认对应关系，只把两组边长随意相除，会得到看似合理但不能推出相似的非例。',
              },
              {
                'title': '比例成立不等于结论自动成立',
                'text': '即使比例式写对了，也不能跳过中间依据直接宣告角相等或长度确定。',
              },
            ],
          },
          {
            'type': 'patterns',
            'title': '规律与模式',
            'patterns': [
              {
                'title': '结论前总有中间桥梁',
                'text': '高质量讲解通常会先说“对应关系成立”，再说“比例成立”，最后才落到长度或角度结论。',
              },
              {
                'title': '越复杂越先回到最稳的对应点',
                'text': '图形一复杂，稳定做法往往都是先回到最明显的一组对应角，再展开后续推理。',
              },
            ],
          },
          {
            'type': 'variations',
            'title': '变式与场景',
            'variations': [
              {
                'title': '图形旋转后仍先找对应角',
                'text': '就算三角形位置旋转或翻折，讲评入口仍然优先回到最稳定的对应角识别。',
              },
              {
                'title': '数据变复杂时先保留中间比例',
                'text': '一旦数字不再整齐，先把比例关系写完整，再做后续长度计算，避免学生在变式里丢步骤。',
              },
            ],
          },
          {
            'type': 'prompts',
            'title': '提示语与追问',
            'prompts': [
              {
                'title': '先让学生说对应关系',
                'text': '你先别急着写比例，先口头说一遍这两条边为什么对应。',
              },
              {
                'title': '追问中间依据',
                'text': '这个结论是直接看到的，还是由哪一步比例关系推出的？',
              },
            ],
          },
          {
            'type': 'outcomes',
            'title': '预期结果',
            'outcomes': [
              {
                'title': '先说清对应关系',
                'text': '学生能先口头说明对应角与对应边，再进入比例式书写。',
              },
              {
                'title': '结论前补出中间依据',
                'text': '学生在长度或角度结论前，能补出比例关系到结论之间的中间理由。',
              },
            ],
          },
          {
            'type': 'principles',
            'title': '原则与指导',
            'principles': [
              {
                'title': '先图后式',
                'description': '先用图形关系建立直观，再进入比例与代数表达。',
              },
              {
                'title': '先局部后整体',
                'description': '先锁定关键边角关系，再回到整体结论的组织。',
              },
            ],
          },
          {
            'type': 'phases',
            'title': '阶段与分段',
            'phases': [
              {
                'title': '识图定位',
                'description': '先识别关键边角和相似关系，不急于列式。',
              },
              {
                'title': '比例转化',
                'description': '把图形关系转成比例表达，再组织推理链。',
              },
            ],
          },
          {
            'type': 'anchors',
            'title': '关键锚点',
            'anchors': [
              {
                'title': '先锁定对应角',
                'description': '先确认相似的判定来源，避免直接硬推比例。',
              },
              {
                'title': '再回到关键边比',
                'description': '把角关系落实成边比，作为后续结论的锚点。',
              },
            ],
          },
          {
            'type': 'priorities',
            'title': '优先关注',
            'priorities': [
              {
                'title': '先稳住判定来源',
                'description': '优先确认相似判定来自哪组角或边，再推进结论。',
              },
              {
                'title': '再检查比例链条',
                'description': '重点核对比例转化是否前后一致，避免中途跳步。',
              },
            ],
          },
          {
            'type': 'assumptions',
            'title': '关键假设',
            'assumptions': [
              {
                'title': '图中对应关系已判定稳定',
                'description': '默认学生已经能识别出相似三角形的对应顶点，不再把识图时间过多消耗在起步阶段。',
                'impact': '如果这一步不稳，后续比例链和板演推进都会明显变慢。',
              },
              {
                'title': '比例转化接受口头先行',
                'description': '默认允许教师先口头建立比例关系，再落回板书整理书面表达。',
                'impact': '这样可以优先保住课堂节奏，再补完整书写规范。',
              },
            ],
          },
          {
            'type': 'dependencies',
            'title': '依赖关系',
            'dependencies': [
              {
                'title': '相似判定',
                'dependsOn': '对应角关系先被确认',
                'description': '只有先把对应角关系讲稳，后面的比例推导和结论迁移才有可靠起点。',
              },
              {
                'title': '比例结论',
                'dependsOn': '相似判定与边比链条',
                'description': '比例结论必须建立在前面相似判定和中间边比链条都成立的前提上。',
              },
            ],
          },
          {
            'type': 'tradeoffs',
            'title': '权衡取舍',
            'tradeoffs': [
              {
                'title': '先口头建模再落板书',
                'pro': '能先把课堂节奏稳住，快速推进到比例推导。',
                'con': '如果后续不及时回收书面表达，学生容易只记结论不记过程。',
              },
              {
                'title': '先板演完整链条再讲结论',
                'pro': '推理结构更完整，便于后续复盘和迁移。',
                'con': '耗时更长，对起步识图不稳的班级会拉低推进速度。',
              },
            ],
          },
          {
            'type': 'alternatives',
            'title': '替代方案',
            'alternatives': [
              {
                'title': '先做口头追问',
                'useWhen': '学生识图还不稳时',
                'description': '先通过口头追问把相似判定来源讲清，再转入板书推导。',
              },
              {
                'title': '先做板演框架',
                'useWhen': '班级表达能力较强时',
                'description': '先让学生搭好比例链条框架，再逐段填入理由和结论。',
              },
            ],
          },
          {
            'type': 'recommendations',
            'title': '建议与后续',
            'recommendations': [
              {
                'title': '先做对应关系复盘',
                'action': '课后 5 分钟小结',
                'description': '把相似判定来源和边比链条再做一次压缩复盘，避免学生只记结果不记依据。',
              },
              {
                'title': '再补一题变式迁移',
                'action': '下一节课起始热身',
                'description': '用结构相近但图形略变的题目检查学生是否能迁移这次的判定与推导路径。',
              },
            ],
          },
          {
            'type': 'risks',
            'title': '风险与应对',
            'risks': [
              {
                'title': '比例链条被学生直接跳写',
                'description': '如果教师只追结论不追中间链条，学生很容易直接写最终比例，导致推理结构断层。',
                'mitigation': '先固定要求学生口头复述每一步比例来源，再允许合并书写。',
              },
              {
                'title': '识图不稳拖慢板演推进',
                'description': '一旦对应边和对应角识别不稳，板演会把时间耗在图形确认上，后面的推导推进明显变慢。',
                'mitigation': '先用 1 分钟小框图复盘对应关系，再进入正式比例推导。',
              },
            ],
          },
          {
            'type': 'triggers',
            'title': '触发条件',
            'triggers': [
              {
                'title': '学生连续两次跳过中间比例链',
                'description': '说明当前班级已经开始只记结论不记推导过程，口头追问不足以稳住结构。',
                'response': '立刻切回板演分步复述，让学生补齐每一步比例来源。',
              },
              {
                'title': '识图讨论停留超过 2 分钟',
                'description': '说明对应边和对应角辨认还没稳，后续推导继续推进只会放大混乱。',
                'response': '先暂停推导，用小框图快速统一对应关系，再恢复主线讲解。',
              },
            ],
          },
          {
            'type': 'thresholds',
            'title': '阈值与容差',
            'thresholds': [
              {
                'title': '识图讨论时长',
                'description': '如果识图确认阶段持续过长，说明当前班级对对应关系仍未稳定。',
                'range': '不超过 2 分钟',
              },
              {
                'title': '板演链条缺失率',
                'description': '如果多数学生在板演里直接跳过中间比例链，说明过程表达还没有压实。',
                'range': '缺失率低于 20%',
              },
            ],
          },
          {
            'type': 'edgeCases',
            'title': '边界情况与例外',
            'edgeCases': [
              {
                'title': '辅助线位置被学生误判',
                'description': '当学生把辅助线理解成已知条件的一部分时，后续比例关系会被整体带偏。',
                'handling': '先明确辅助线是讲解工具，再重新界定哪些关系来自题干、哪些来自构造。',
              },
              {
                'title': '图形接近对称但并非严格对称',
                'description': '学生容易因为视觉上“像”而直接套用对称关系，导致错误判定。',
                'handling': '要求先写出可验证的角边关系，再决定是否允许借助对称直觉。',
              },
            ],
          },
          {
            'type': 'flags',
            'title': '关注信号与标记',
            'flags': [
              {
                'title': '学生开始只抄结论',
                'description': '板书上只保留最终比例或结论，推理依据逐步消失。',
                'meaning': '说明过程表达已经开始失稳，需要马上把中间链条拉回来。',
              },
              {
                'title': '讨论集中在图形外观',
                'description': '学生更多在说“看起来像”“应该差不多”，而不是列可验证关系。',
                'meaning': '说明课堂开始依赖直觉判断，应切回可验证条件。',
              },
            ],
          },
          {
            'type': 'reviewPoints',
            'title': '复盘点与回看清单',
            'reviewPoints': [
              {
                'title': '相似判定来源是否说清',
                'description': '回看学生是否能完整说出相似判定来自哪组角边关系，而不是直接引用结论。',
                'check': '让学生用 30 秒复述“为什么能判相似”。',
              },
              {
                'title': '比例链条是否保留中间环节',
                'description': '回看板演和作答中是否保留了关键比例链，而不是只剩最终结论。',
                'check': '随机抽 2 份板演，看中间链条是否完整。',
              },
            ],
          },
          {
            'type': 'antiPatterns',
            'title': '反模式与不推荐做法',
            'antiPatterns': [
              {
                'title': '直接给最终结论再倒推理由',
                'description': '学生会优先记结果，后续补理由时更像事后拼接，推理链不稳。',
                'saferAlternative': '先让学生口头复述每一步关系，再落到最终结论。',
              },
              {
                'title': '用图形直觉替代可验证关系',
                'description': '“看起来像”“应该差不多”会让后续判定建立在不稳前提上。',
                'saferAlternative': '先列角边关系，再决定是否允许借助直观判断。',
              },
            ],
          },
          {
            'type': 'dosAndDonts',
            'title': '宜做与忌做',
            'dosAndDonts': {
              'dos': [
                '先让学生复述每一步比例来源，再给最终结论。',
                '先列可验证关系，再允许借助图形直观判断。',
              ],
              'donts': [
                '不要把最终结论先写满黑板，再倒推理由。',
                '不要用“看起来像”代替角边关系验证。',
              ],
            },
            'guardrails': [
              '一旦板演里连续出现省略链条，就必须切回分步复述。',
            ],
          },
          {
            'type': 'watchFors',
            'title': '持续观察点',
            'watchFors': [
              {
                'title': '学生是否主动补中间比例链',
                'description': '看学生在没有提示时，是否仍会把中间比例链补全到位。',
                'interpretation': '如果开始主动补链条，说明过程表达已经逐渐内化。',
              },
              {
                'title': '讨论是否转向可验证关系',
                'description': '看学生在讨论时，是否更多引用角边关系，而不是外观直觉。',
                'interpretation': '如果讨论依据开始稳定，后续迁移题更容易讲透。',
              },
            ],
          },
          {
            'type': 'successCriteria',
            'title': '成功标准与退出条件',
            'successCriteria': [
              {
                'title': '学生能独立复述判定链条',
                'description': '学生在没有教师提示时，能完整说出从判定到比例再到结论的关键链条。',
                'signal': '随机抽问时能在 30 秒内复述清楚。',
              },
              {
                'title': '板演保留中间比例链',
                'description': '学生的板演和书写不再只剩结论，能保留关键比例过渡。',
                'signal': '抽样板演里中间链条保留率明显上升。',
              },
            ],
          },
          {
            'type': 'failureModes',
            'title': '可能失效点与预演风险',
            'failureModes': [
              {
                'title': '学生只记住结论，不保留判定链',
                'description': '如果讲评只强调最后比例和结论，学生很容易把中间判定链再次省掉。',
                'mitigation': '板书时强制保留“判定依据 -> 比例链 -> 结论”三段式，并在抽问时只追问中间链条。',
              },
              {
                'title': '讨论重新回到直观感觉',
                'description': '如果追问停在“看起来相似”，学生会把后续论证重新拉回经验判断。',
                'mitigation': '把追问改成“哪两组角/边支撑这个判断”，迫使讨论回到可验证关系。',
              },
            ],
          },
          {
            'type': 'decisionCriteria',
            'title': '决策标准与选择依据',
            'decisionCriteria': [
              {
                'title': '优先选择可复述的判定链',
                'description': '讲评时优先保留学生能复述出来的判定链，而不是只保留最终结论。',
                'rationale': '这样后续迁移题里更容易复现同一套推理路径。',
              },
              {
                'title': '优先选择可验证关系',
                'description': '当直观感觉和可验证关系冲突时，优先按可验证关系组织板书与追问。',
                'rationale': '可验证关系更稳定，也更利于课堂讨论达成共识。',
              },
            ],
          },
          {
            'type': 'goNoGo',
            'title': '继续推进与暂停观察信号',
            'goNoGo': [
              {
                'title': '学生能复述完整判定链',
                'description': '如果学生已经能独立复述从判定到比例再到结论的链条，可以继续推进变式。',
                'decision': '继续推进到变式题，让学生自己迁移这条链。',
              },
              {
                'title': '讨论仍停在“看起来相似”',
                'description': '如果学生讨论还停在外观直觉，没有回到角边关系，就先不要切到下一题。',
                'decision': '暂停推进，先把可验证关系重新板书并抽问两轮。',
              },
            ],
          },
          {
            'type': 'alignment',
            'title': '对齐与一致性检查',
            'alignment': [
              {
                'title': '板书链条是否和口头追问一致',
                'description': '检查板书是否真的保留了口头追问里强调的判定链，而不是口头说一套、板书写一套。',
                'result': '如果两者一致，学生复述时更不容易漏掉中间推理。',
              },
              {
                'title': '示例与变式是否共用同一判断标准',
                'description': '检查示例题和后续变式题是否都回到了同一套可验证关系，而不是换成另一套直觉描述。',
                'result': '如果标准一致，迁移练习时学生更容易把旧链条迁过去。',
              },
            ],
          },
          {
            'type': 'roles',
            'title': '角色与分工',
            'roles': [
              {
                'role': '教师追问',
                'responsibility': '负责追问相似判定来源，避免学生直接跳到比例结论。',
              },
              {
                'role': '学生板演',
                'responsibility': '负责把关键边比整理到板书上，形成清晰推理链。',
              },
            ],
          },
          {
            'type': 'stakeholders',
            'title': '相关角色与参与方',
            'stakeholders': [
              {
                'name': '主讲教师',
                'description': '负责推进关键追问，并决定何时从识图切到比例推导。',
                'relation': '直接影响课堂节奏与讲评收束点。',
              },
              {
                'name': '学生板演',
                'description': '负责把对应边与比例关系外显到板书上，暴露真实理解状态。',
                'relation': '影响纠错顺序和后续例题展开方式。',
              },
              {
                'name': '听课教研员',
                'description': '负责记录误区暴露点与收束是否有效，供课后复盘。',
                'relation': '关注讲评是否覆盖核心误区与迁移方法。',
              },
            ],
          },
          {
            'type': 'owners',
            'title': '负责人与归属关系',
            'owners': [
              {
                'owner': '主讲教师',
                'description': '负责讲评推进、关键追问与课堂收束。',
                'ownership': '课堂节奏与板书主线',
              },
              {
                'owner': '学生板演',
                'description': '负责把关键比例关系及时写出，便于全班共视。',
                'ownership': '板书链条与示例呈现',
              },
              {
                'owner': '教研记录',
                'description': '负责记录误区暴露点和讲评修正节点。',
                'ownership': '课后复盘与后续优化建议',
              },
            ],
          },
          {
            'type': 'coverage',
            'title': '覆盖范围与适用边界',
            'coverage': [
              {
                'area': '相似判定链',
                'description': '本轮讲评重点覆盖从识图到比例推导的完整主链，不展开额外证明变式。',
                'boundary': '适用于当前这类基础相似关系题，不直接覆盖综合压轴变式。',
              },
              {
                'area': '板书收束',
                'description': '只保留能帮助学生复述的关键比例与对应关系，不追求完整课堂逐字记录。',
                'boundary': '超过两层迁移的延展题留到课后讲义，不塞进本节课堂板书。',
              },
            ],
          },
          {
            'type': 'inputsOutputs',
            'title': '输入与输出',
            'inputs': [
              {
                'name': '识图结果',
                'description': '学生先说清对应角和对应边，作为比例推导入口。',
                'note': '必须先口头确认，不直接写比例式。',
              },
              {
                'name': '板书骨架',
                'description': '黑板上保留关键对应关系与比例链条。',
                'note': '只记录帮助复述的最小必要信息。',
              },
            ],
            'outputs': [
              {
                'name': '完整比例推导',
                'description': '学生能从识图一路说到比例关系与结论。',
                'quality': '最终应能独立复述完整判定链。',
              },
              {
                'name': '讲评收束结论',
                'description': '全班对本题方法边界与迁移条件形成一致认识。',
                'quality': '能区分本题主链与课后延展部分。',
              },
            ],
          },
          {
            'type': 'conditions',
            'title': '前置条件与完成条件',
            'preconditions': [
              {
                'title': '识图已对齐',
                'description': '学生先能说清对应角和对应边，避免后续比例链从错误对象开始。',
                'check': '口头复述时不再混淆对应关系。',
              },
              {
                'title': '板书骨架已建立',
                'description': '黑板上已经留出关键比例与结论位置，便于后续收束。',
                'check': '板书不需要临时大幅重排。',
              },
            ],
            'postconditions': [
              {
                'title': '完整链条可复述',
                'description': '学生能够从识图一路复述到比例推导与结论。',
                'signal': '不依赖教师提示也能说出中间依据。',
              },
              {
                'title': '适用边界已澄清',
                'description': '全班明确哪些变式留到课后处理，哪些属于本节范围。',
                'signal': '不会把课后延展误当成本题主链的一部分。',
              },
            ],
          },
          {
            'type': 'artifacts',
            'title': '过程产物与交付物',
            'artifacts': [
              {
                'name': '课堂板书主链',
                'description': '保留从识图到比例推导的最小必要板书，用于课堂内复述。',
                'format': '黑板主链 + 关键比例式',
              },
              {
                'name': '课后讲评讲义',
                'description': '补充本节没有展开的延展变式与迁移提醒。',
                'format': '课后 PDF 讲义',
              },
            ],
          },
          {
            'type': 'handoverNotes',
            'title': '交接说明与执行备注',
            'handoverNotes': [
              {
                'title': '下一位授课教师接手时先检查板书留存',
                'description': '如果继续讲延展变式，先确认主链板书是否仍然可读，不要直接擦掉重写。',
                'action': '先复述主链，再切到延展变式。',
              },
              {
                'title': '课后讲义发放前补迁移提醒',
                'description': '发讲义前确认已注明哪些变式属于课后阅读，不回灌到本节主线。',
                'action': '在讲义首页补“本节范围 / 课后延展”标识。',
              },
            ],
          },
          {
            'type': 'acceptance',
            'title': '验收标准与确认结论',
            'acceptance': [
              {
                'criterion': '主链板书可独立复述',
                'description': '学生离开教师提示后，仍能按板书顺序完整复述关键推理链。',
                'status': '满足后可视为本节主链讲评已收束。',
              },
              {
                'criterion': '延展内容已明确下沉到讲义',
                'description': '课堂里不再继续拉长主线，而是把延展变式转交课后讲义。',
                'status': '满足后可停止课堂扩写，进入收尾。',
              },
            ],
          },
          {
            'type': 'followUpOwners',
            'title': '后续责任人与动作归属',
            'followUpOwners': [
              {
                'owner': '主讲教师',
                'description': '负责确认课堂主链已经完整收束，再决定是否布置延展阅读。',
                'scope': '课堂收尾与讲义发放前确认',
              },
              {
                'owner': '教研记录',
                'description': '负责把误区暴露点与本轮收束判断同步到课后复盘记录。',
                'scope': '复盘文档与后续改进建议',
              },
            ],
          },
          {
            'type': 'verification',
            'title': '复核校验与审查检查',
            'verification': [
              {
                'check': '主链板书和讲义首页范围是否一致',
                'description': '检查课堂收束时说的范围和课后讲义标注的范围是否一致。',
                'outcome': '一致时可避免课后扩散误解。',
              },
              {
                'check': '后续责任归属是否已写清',
                'description': '确认谁负责发讲义、谁负责记录复盘、谁负责跟进延展部分。',
                'outcome': '写清后可避免收尾动作悬空。',
              },
            ],
          },
          {
            'type': 'serviceLevels',
            'title': '服务水平与响应预期',
            'serviceLevels': [
              {
                'service': '课堂追问反馈',
                'description': '学生在主链推理处卡住时，教师应在同一轮追问里给出最小提示，不把反馈拖到课后。',
                'target': '关键卡点 30 秒内给出引导性追问。',
              },
              {
                'service': '课后讲义补充',
                'description': '延展内容如需转移到讲义，应在本节结束后尽快发出，避免学生等待期间失去上下文。',
                'target': '课后 10 分钟内完成讲义下发与备注同步。',
              },
            ],
          },
          {
            'type': 'escalations',
            'title': '升级处理路径',
            'escalations': [
              {
                'trigger': '课堂主链仍出现连续空转',
                'description': '同一追问轮次里两次提示后仍无法重新收束到主线时，不再继续现场拉长。',
                'route': '立即切到讲义补充说明，并由主讲教师课后单独跟进。',
              },
              {
                'trigger': '讲义与板书范围出现不一致',
                'description': '发现课堂口头结论和课后资料首页标注范围不一致时，不能直接发放旧版本讲义。',
                'route': '先通知教研记录修正文档，再由主讲教师确认后统一下发。',
              },
            ],
          },
          {
            'type': 'escalationContacts',
            'title': '升级接手人与联络对象',
            'escalationContacts': [
              {
                'contact': '主讲教师',
                'role': '负责在课堂现场决定是否停止继续扩写，并切到讲义补充说明。',
                'channel': '课堂即时口头决策 + 课后讲义备注确认',
              },
              {
                'contact': '教研记录',
                'role': '负责接手文档修正与复盘同步，避免升级后信息断层。',
                'channel': '复盘文档更新 + 群内同步修正版讲义链接',
              },
            ],
          },
          {
            'type': 'reviewCadence',
            'title': '回看节奏与同步周期',
            'reviewCadence': [
              {
                'stage': '课堂结束后首次回看',
                'description': '先确认主链是否真的收束，以及讲义补充是否已经同步到学生侧。',
                'cadence': '课后 10 分钟内完成首次复核。',
              },
              {
                'stage': '课后复盘同步',
                'description': '把误区暴露点、升级处理和讲义修正同步到教研复盘记录。',
                'cadence': '当天晚些时候完成一次集中同步。',
              },
            ],
          },
          {
            'type': 'notificationPaths',
            'title': '通知路径与同步路由',
            'notificationPaths': [
              {
                'audience': '主讲教师与教研记录',
                'description': '用于确认课堂是否已经收束，以及讲义修正版是否可对外发放。',
                'path': '群内同步修正版链接 + 复盘文档备注。',
              },
              {
                'audience': '学生侧讲义接收对象',
                'description': '用于在课后统一补发延展讲义和范围修正说明。',
                'path': '班级通知渠道 + 讲义首页追加修正说明。',
              },
            ],
          },
          {
            'type': 'notifyTriggers',
            'title': '通知触发条件',
            'notifyTriggers': [
              {
                'trigger': '讲义修正版已确认',
                'description': '只有在主讲教师确认讲义范围和课堂口头结论一致后，才进入对外通知。',
                'signal': '修正版链接已可发放，且首页修正说明已补齐。',
              },
              {
                'trigger': '课堂主链仍未收束',
                'description': '如果课堂结束前仍存在未闭环点，需要立即通知教研记录和后续接手人。',
                'signal': '出现无法在本轮课堂内收束的延展分支。',
              },
            ],
          },
          {
            'type': 'responsePriorities',
            'title': '响应优先级与分诊顺序',
            'responsePriorities': [
              {
                'priority': '先修正讲义范围',
                'description': '如果课堂结论和讲义首页范围不一致，优先处理资料一致性，再做后续通知。',
                'order': '第一优先级，先改资料后发通知。',
              },
              {
                'priority': '再同步接手人与复盘记录',
                'description': '资料一致后，再把升级处理、接手人和后续动作同步到教研记录。',
                'order': '第二优先级，避免通知链条先于事实更新。',
              },
            ],
          },
          {
            'type': 'responseWindows',
            'title': '响应时窗与升级时限',
            'responseWindows': [
              {
                'stage': '讲义修正版确认',
                'description': '在对外通知前，先完成资料一致性修正与版本确认。',
                'window': '课后 10 分钟内完成首轮修正。',
              },
              {
                'stage': '升级后复盘同步',
                'description': '一旦进入升级处理，必须在同一天内完成复盘记录和后续接手同步。',
                'window': '当天内完成升级闭环与记录回填。',
              },
            ],
          },
          {
            'type': 'notificationWindows',
            'title': '通知时窗与提醒时限',
            'notificationWindows': [
              {
                'stage': '课堂结论确认后首发通知',
                'description': '只有在课堂结论和修正版讲义范围确认一致后，才进入首轮同步通知。',
                'window': '课后 15 分钟内完成首轮通知。',
              },
              {
                'stage': '升级提醒补发',
                'description': '如果进入升级处理，需要把升级原因、接手人和回看节奏再次同步给相关对象。',
                'window': '升级后 30 分钟内补发提醒。',
              },
            ],
          },
          {
            'type': 'notificationRecipients',
            'title': '通知对象与提醒接收方',
            'notificationRecipients': [
              {
                'audience': '主讲教师与备课负责人',
                'description': '首轮通知先覆盖课堂主责任人，确认修正版讲义范围和对外口径一致。',
                'channel': '租户内教研群 + 讲义版本备注',
              },
              {
                'audience': '后续接手人与复盘记录人',
                'description': '如果进入升级处理，需要把升级原因、接手人和后续动作同步到闭环记录。',
                'channel': '升级记录卡 + 课后复盘同步',
              },
            ],
          },
          {
            'type': 'notificationPayloads',
            'title': '通知内容与提醒载荷',
            'notificationPayloads': [
              {
                'subject': '讲义修正版首轮通知',
                'message': '同步修正版讲义链接、课堂结论摘要和后续是否需要升级处理。',
                'template': '讲义链接 + 课堂结论 + 是否升级',
              },
              {
                'subject': '升级提醒补发',
                'message': '补充升级原因、接手人、回看节奏和闭环记录入口。',
                'template': '升级原因 + 接手人 + 回看节奏',
              },
            ],
          },
          {
            'type': 'notificationOutcomes',
            'title': '通知结果与回执状态',
            'notificationOutcomes': [
              {
                'result': '首轮通知已送达主讲教师',
                'description': '主讲教师已确认修正版讲义链接和课堂结论摘要一致。',
                'status': '已读并确认继续后续同步',
              },
              {
                'result': '升级提醒已进入闭环记录',
                'description': '后续接手人与复盘记录人已收到升级原因和回看节奏补充信息。',
                'status': '记录已创建，等待闭环回填',
              },
            ],
          },
          {
            'type': 'notificationFailures',
            'title': '通知失败与补救动作',
            'notificationFailures': [
              {
                'failure': '首轮通知未覆盖接手人',
                'description': '如果只同步了主讲教师而遗漏后续接手人，升级链条会出现信息断层。',
                'recovery': '立即补发升级摘要，并在闭环记录里补登记接手人。',
              },
              {
                'failure': '提醒时限超过但未补发',
                'description': '一旦超过提醒时限仍未补发升级通知，后续回看节奏会失真。',
                'recovery': '先补发提醒，再把超时原因和新时限写入复盘记录。',
              },
            ],
          },
          {
            'type': 'notificationChecks',
            'title': '通知发前核对清单',
            'notificationChecks': [
              {
                'check': '修正版讲义链接已更新',
                'description': '确认通知里引用的是最新版本讲义，而不是旧链接或旧口径。',
                'status': '已核对最新版本号与课堂结论一致',
              },
              {
                'check': '接手人与复盘入口已补齐',
                'description': '确认通知里已经带上升级接手人、回看节奏和闭环记录入口。',
                'status': '已补齐升级摘要与复盘入口',
              },
            ],
          },
          {
            'type': 'notificationDependencies',
            'title': '通知依赖与前置同步项',
            'notificationDependencies': [
              {
                'dependency': '修正版讲义首页说明',
                'description': '通知前必须先确认首页范围说明已经与课堂结论同步更新。',
                'source': '讲义修订负责人',
              },
              {
                'dependency': '升级接手人与复盘入口',
                'description': '只有接手人、回看节奏和闭环记录入口都准备好，通知链才不会断。',
                'source': '升级处理记录卡',
              },
            ],
          },
          {
            'type': 'notificationDecisions',
            'title': '通知决策与分发结论',
            'notificationDecisions': [
              {
                'decision': '先发修正版通知，再发升级提醒',
                'description': '先保证资料一致，再进入升级和接手同步，避免接收方先看到过期结论。',
                'outcome': '首轮发放修正版，升级提醒在补充接手人后再发。',
              },
              {
                'decision': '只对主责任人首发，其他对象二次同步',
                'description': '当课堂主链仍在确认时，先控收件面，避免对外口径过早扩散。',
                'outcome': '主讲教师先确认，接手人与复盘记录人随后补发。',
              },
            ],
          },
          {
            'type': 'notificationSummaries',
            'title': '通知摘要与同步概览',
            'notificationSummaries': [
              {
                'summaryTitle': '首轮同步摘要',
                'summary': '包含修正版讲义链接、课堂结论摘要以及是否需要升级处理的判断。',
                'scope': '主讲教师、备课负责人',
              },
              {
                'summaryTitle': '升级链路摘要',
                'summary': '补充升级原因、接手人、回看节奏和复盘入口，确保后续闭环不丢信息。',
                'scope': '接手人、复盘记录人',
              },
            ],
          },
          {
            'type': 'notificationMetrics',
            'title': '通知指标与回看信号',
            'notificationMetrics': [
              {
                'metric': '首轮通知确认率',
                'description': '关注首轮通知是否被主责任人及时确认，避免修正版口径滞后。',
                'signal': '课后 15 分钟内收到主讲教师确认。',
              },
              {
                'metric': '升级补发闭环率',
                'description': '关注升级提醒是否真正进入闭环记录，而不是只停留在群消息里。',
                'signal': '当天内补齐接手人、回看节奏和记录入口。',
              },
            ],
          },
          {
            'type': 'notificationAudits',
            'title': '通知审计与留痕记录',
            'notificationAudits': [
              {
                'event': '首轮通知已写入教研记录',
                'description': '修正版讲义链接、课堂结论摘要和发送对象已同步进入教研记录。',
                'trace': '教研记录卡 + 发送时间戳',
              },
              {
                'event': '升级补发已留痕',
                'description': '升级原因、接手人和回看节奏的补发动作已经进入闭环追踪。',
                'trace': '升级记录卡 + 闭环入口引用',
              },
            ],
          },
          {
            'type': 'notificationPolicies',
            'title': '通知策略与执行约定',
            'notificationPolicies': [
              {
                'policy': '先发摘要，再补上下文',
                'description': '先同步修订结论、适用范围和处理优先级，再补讲义链接与板书说明，避免群消息过长被忽略。',
                'rule': '首条消息控制在 3 个要点内，补充材料放第二条。',
              },
              {
                'policy': '升级提醒必须附闭环入口',
                'description': '进入升级处理路径时，必须带上交接记录与回看入口，避免消息只停留在提醒层。',
                'rule': '所有升级消息都要附上接手人、回看时间和记录卡引用。',
              },
            ],
          },
          {
            'type': 'notificationChannels',
            'title': '通知渠道与分发介质',
            'notificationChannels': [
              {
                'channel': '班级群快速同步',
                'description': '用于先发修订摘要和课堂结论，保证所有教师先看到结论而不是附件。',
                'route': '班级群首条摘要 + 第二条补充链接',
              },
              {
                'channel': '教研记录卡',
                'description': '用于沉淀最终版本、升级原因和后续回看入口，避免消息沉没后找不到闭环证据。',
                'route': '教研记录卡正文 + 升级追踪引用',
              },
            ],
          },
          {
            'type': 'notificationOwners',
            'title': '通知负责人与归属关系',
            'notificationOwners': [
              {
                'owner': '备课负责人',
                'description': '负责首轮修订摘要的准确性与发送时机，确保先发出课堂结论与适用范围。',
                'ownership': '首轮同步内容正确性与发布时间',
              },
              {
                'owner': '教研接手人',
                'description': '负责升级补发、闭环回看和记录卡维护，避免提醒停在分发层。',
                'ownership': '升级路径闭环、回看节奏与记录入口维护',
              },
            ],
          },
          {
            'type': 'notificationEscalations',
            'title': '通知升级路径与接手动作',
            'notificationEscalations': [
              {
                'stage': '首轮同步未确认阅读',
                'description': '如果班级群首轮摘要在约定时窗内没有收到关键教师确认，就进入升级提醒。',
                'action': '转交教研接手人补发，并附闭环记录入口。',
              },
              {
                'stage': '升级补发后仍缺闭环记录',
                'description': '如果升级提醒已发出，但记录卡仍未补齐接手人与回看时间，就继续上提。',
                'action': '由备课负责人发起二次跟进，并在教研记录卡内补齐责任链。',
              },
            ],
          },
          {
            'type': 'notificationTemplates',
            'title': '通知模板与推荐文案',
            'notificationTemplates': [
              {
                'template': '首轮修订摘要模板',
                'description': '用于首轮快速同步修订结论、适用范围和后续补充材料入口。',
                'copy': '【修订摘要】先看三点结论：1）适用范围；2）替换页面；3）补充链接见下一条。',
              },
              {
                'template': '升级补发模板',
                'description': '用于在未确认阅读或未补齐闭环记录时进行升级提醒。',
                'copy': '【升级提醒】本条需由接手人完成闭环补录：原因、回看时间、记录入口已附，请今日内补齐。',
              },
            ],
          },
          {
            'type': 'notificationApprovals',
            'title': '通知审批与确认环节',
            'notificationApprovals': [
              {
                'step': '首轮摘要发前确认',
                'description': '在群发前先由备课负责人确认结论、范围和链接入口是否一致。',
                'confirmation': '至少核对修订点、适用班级和补充材料入口三项。',
              },
              {
                'step': '升级补发确认闭环',
                'description': '升级提醒发出后，需要确认接手人、回看时间和记录入口已补齐。',
                'confirmation': '收到接手人确认并完成记录卡更新后才算闭环。',
              },
            ],
          },
          {
            'type': 'notificationStates',
            'title': '通知状态与当前阶段',
            'notificationStates': [
              {
                'state': '首轮摘要已发出',
                'description': '修订结论和适用范围已经完成第一轮同步，等待关键教师确认阅读。',
                'phase': '等待确认',
              },
              {
                'state': '升级提醒已补发',
                'description': '升级路径已经启动，当前重点是补齐接手人、回看时间与记录入口。',
                'phase': '补录闭环',
              },
            ],
          },
          {
            'type': 'notificationHistory',
            'title': '通知历史与变更轨迹',
            'notificationHistory': [
              {
                'event': '首轮修订摘要已发出',
                'description': '完成第一轮班级群同步，并附上修订要点与补充材料入口。',
                'timestamp': '第 1 节课后 10 分钟',
              },
              {
                'event': '升级补发已进入闭环',
                'description': '由于未确认阅读，已发起升级补发，并补齐接手人和记录入口。',
                'timestamp': '当天教研会前',
              },
            ],
          },
          {
            'type': 'notificationRetries',
            'title': '通知补救与重试策略',
            'notificationRetries': [
              {
                'retry': '首轮未确认的二次提醒',
                'description': '若首轮摘要在约定时窗内没有关键教师确认，则进行一次更短、更聚焦的补发。',
                'timing': '30 分钟后补发一次，仅保留结论、范围和闭环入口。',
              },
              {
                'retry': '升级后仍未闭环的补救',
                'description': '如果升级提醒已发出但记录卡仍不完整，则由接手人改走记录驱动而非继续堆消息。',
                'fallback': '优先补齐记录卡并@责任人，不再连续追加群消息。',
              },
            ],
          },
          {
            'type': 'notificationFallbacks',
            'title': '通知兜底路径与备用动作',
            'notificationFallbacks': [
              {
                'fallback': '班级群未及时确认后的教师侧兜底',
                'description': '如果班级群内未出现关键确认，则改由备课组小群同步结论、适用范围和记录入口。',
                'route': '备课组小群同步 -> @当天值班教师 -> 回填记录卡确认时间',
              },
              {
                'fallback': '升级提醒后仍未形成闭环的备用动作',
                'description': '若升级提醒已发但仍无人补齐记录，则由责任人直接改走任务卡闭环，不继续在原群追加消息。',
                'owner': '责任人接手 -> 建立任务卡 -> 在下次教研同步时统一回顾',
              },
            ],
          },
          {
            'type': 'notificationExceptions',
            'title': '通知例外情况与特殊处理',
            'notificationExceptions': [
              {
                'exception': '当日代课教师不在原通知链路内',
                'description': '若当天由代课教师接手班级，但不在默认群组同步链路中，需要先补齐同步对象再发摘要。',
                'handling': '先补充代课教师到同步链路，再补发一次仅含结论与入口的短摘要。',
              },
              {
                'exception': '家长群同步被暂缓',
                'description': '若教研结论涉及尚未复核的课堂修订，不直接同步到家长群，只保留内部教师链路。',
                'exceptionPath': '保留教师侧记录卡与班级群同步，待复核完成后再决定是否外发。',
              },
            ],
          },
          {
            'type': 'notificationOverrides',
            'title': '通知覆盖规则与特批调整',
            'notificationOverrides': [
              {
                'override': '周末值班群覆盖默认班级群同步',
                'description': '在周末答疑场景下，不沿用工作日班级群链路，而改走值班群同步，以减少无关教师干扰。',
                'basis': '值班安排生效期间，由值班负责人统一确认并代替班级链路接收。',
              },
              {
                'override': '临时停课日仅保留内部同步',
                'description': '如遇临时停课，不向学生链路发出课堂修订通知，只保留教师和教研内部同步。',
                'approval': '由年级负责人确认当天停课安排后，启用内部同步覆盖规则。',
              },
            ],
          },
          {
            'type': 'notificationGuardrails',
            'title': '通知边界与执行护栏',
            'notificationGuardrails': [
              {
                'guardrail': '同一事项不连续轰炸群消息',
                'description': '同一修订事项在一个课节内最多进行一次补发，超过后改走记录卡与责任人私聊闭环。',
                'limit': '群内最多 2 次触达，之后必须切换到记录驱动闭环。',
              },
              {
                'guardrail': '未复核结论不得外发家长链路',
                'description': '涉及课堂修订但尚未完成复核的结论，只能留在教师侧同步，不向家长侧外发。',
                'boundary': '教师链路可见，家长链路冻结，待复核通过后再决定是否外发。',
              },
            ],
          },
          {
            'type': 'notificationPrereqs',
            'title': '通知前置条件与发前准备',
            'notificationPrereqs': [
              {
                'prereq': '修订结论已由主备教师确认',
                'description': '在发出任何摘要前，需要先完成主备教师对修订结论、适用范围和材料入口的确认。',
                'readyWhen': '结论、范围、入口三项都已写入记录卡并通过主备确认。',
              },
              {
                'prereq': '同步对象名单已更新到当天值班链路',
                'description': '若当天存在代课或轮值调整，需要先更新同步对象名单，避免发出后再回补。',
                'gate': '当天值班教师、代课教师与年级负责人三方都已进入通知链路。',
              },
            ],
          },
          {
            'type': 'notificationAudienceRules',
            'title': '通知对象与分发规则',
            'notificationAudienceRules': [
              {
                'audience': '班级授课教师',
                'description': '接收完整修订摘要、适用范围和材料入口，用于课堂执行和跟进。',
                'delivery': '完整摘要 + 材料入口 + 记录卡链接',
              },
              {
                'audience': '年级负责人',
                'description': '只接收结论、风险和闭环状态，用于判断是否需要升级处理。',
                'format': '简版结论 + 风险标记 + 闭环状态',
              },
            ],
          },
          {
            'type': 'notificationVariants',
            'title': '通知版本与表达变体',
            'notificationVariants': [
              {
                'variant': '教师侧完整版本',
                'description': '包含修订结论、适用范围、材料入口和闭环记录，适合直接执行与回顾。',
                'usage': '教研群 / 授课教师链路使用完整版本。',
              },
              {
                'variant': '负责人简版版本',
                'description': '只保留结论、风险和当前闭环状态，用于快速判断是否需要升级。',
                'whenToUse': '年级负责人或值班负责人只看快速决策信息时使用简版。',
              },
            ],
          },
          {
            'type': 'notificationCadences',
            'title': '通知节奏与发送频率',
            'notificationCadences': [
              {
                'stage': '初次同步',
                'description': '结论形成后 10 分钟内同步首版信息，避免授课链路滞后。',
                'cadence': '形成结论后 10 分钟内发首版',
              },
              {
                'stage': '风险升级',
                'description': '一旦出现跨班级风险或执行阻塞，立即补发升级提醒并抄送负责人。',
                'frequency': '命中升级条件后立即补发',
              },
            ],
          },
          {
            'type': 'notificationScopes',
            'title': '通知范围与适用边界',
            'notificationScopes': [
              {
                'scope': '班级内执行同步',
                'description': '面向当前授课班级的授课教师与备课协同者，用于即时执行修订动作。',
                'boundary': '仅限当前班级与同备课组成员查看完整执行信息。',
              },
              {
                'scope': '年级级风险通报',
                'description': '面向年级负责人和值班负责人，只同步需要决策的风险结论。',
                'appliesTo': '跨班级影响、可能引发统一口径调整时才升级到年级级通报。',
              },
            ],
          },
          {
            'type': 'notificationBundles',
            'title': '通知组合包与配套内容',
            'notificationBundles': [
              {
                'bundle': '课堂执行包',
                'description': '用于授课教师即时执行修订动作，强调清晰、可直接落地。',
                'includes': '修订摘要、板书提示、材料入口、闭环记录卡',
              },
              {
                'bundle': '负责人判断包',
                'description': '用于负责人快速判断是否需要升级、追责或统一口径调整。',
                'attachments': '风险结论、影响范围、当前闭环状态、下一步建议',
              },
            ],
          },
          {
            'type': 'notificationExclusions',
            'title': '通知排除项与不发送对象',
            'notificationExclusions': [
              {
                'target': '仅旁听教师',
                'description': '不直接承担当前课堂执行动作，不需要接收完整修订与追踪信息。',
                'reason': '避免旁听链路收到大量执行性通知，造成噪音。',
              },
              {
                'target': '无关联学科负责人',
                'description': '与当前问题不在同一学科或同一教研口径，不纳入升级链路。',
                'whyExcluded': '只保留对当前结论有决策或协同价值的接收方。',
              },
            ],
          },
          {
            'type': 'notificationThresholds',
            'title': '通知阈值与触发门槛',
            'notificationThresholds': [
              {
                'threshold': '跨班级影响阈值',
                'description': '当同一问题影响两个及以上班级的执行口径时，需要升级到年级负责人。',
                'trigger': '影响班级数 >= 2',
              },
              {
                'threshold': '课堂阻塞阈值',
                'description': '当修订内容无法在当前课节内完成替换时，需要立刻补发风险提醒。',
                'condition': '当前课节内无法落地修订动作',
              },
            ],
          },
          {
            'type': 'notificationMatrices',
            'title': '通知矩阵与分发视图',
            'notificationMatrices': [
              {
                'matrix': '角色 x 风险等级',
                'description': '按接收角色和风险等级决定通知深度与响应动作。',
                'axes': '接收角色 × 风险等级',
              },
              {
                'matrix': '范围 x 时效',
                'description': '按影响范围和时效要求判断是否需要即时补发或升级。',
                'dimensions': '影响范围 × 处理时限',
              },
            ],
          },
          {
            'type': 'notificationSequences',
            'title': '通知顺序与发送链路',
            'notificationSequences': [
              {
                'step': '先发授课教师',
                'description': '先让一线执行者拿到完整修订信息，保证课堂不等待。',
                'order': '第 1 步',
              },
              {
                'step': '再发负责人',
                'description': '当确认存在跨班级影响或风险升级时，再补发负责人链路。',
                'sequence': '第 2 步',
              },
            ],
          },
          {
            'type': 'notificationPoliciesets',
            'title': '通知规则集与执行口径',
            'notificationPoliciesets': [
              {
                'policy': '课堂即时修订规则',
                'description': '与当前课堂直接相关的修订信息优先走即时同步，不等待课后汇总。',
                'rule': '影响当前课节执行时必须实时同步。',
              },
              {
                'policy': '负责人升级判断规则',
                'description': '只有命中跨班级影响或升级阈值时，才进入负责人链路。',
                'standard': '未命中升级门槛时不额外扩散通知面。',
              },
            ],
          },
          {
            'type': 'notificationPlaybooks',
            'title': '通知执行手册与操作脚本',
            'notificationPlaybooks': [
              {
                'playbook': '课堂即时修订脚本',
                'description': '先同步一线执行者，再记录修订落地结果，最后补负责人链路。',
                'script': '授课教师 -> 备课协同者 -> 年级负责人',
              },
              {
                'playbook': '风险升级处理脚本',
                'description': '命中升级阈值后立即补发风险提醒，并附当前闭环状态。',
                'operatorNote': '先补发风险结论，再补状态快照与下一步动作。',
              },
            ],
          },
          {
            'type': 'notificationBundlesets',
            'title': '通知成套分发包与内容组合',
            'notificationBundlesets': [
              {
                'bundleSet': '授课执行组合包',
                'description': '面向授课教师的一次性组合内容，确保信息到位即可执行。',
                'contains': '修订摘要、板书提示、课堂材料入口、闭环记录卡',
              },
              {
                'bundleSet': '升级判断组合包',
                'description': '面向负责人的最小决策包，只保留影响判断和动作推进所需内容。',
                'set': '风险结论、影响范围、当前状态、建议动作',
              },
            ],
          },
          {
            'type': 'notificationCheckpoints',
            'title': '通知检查点与关键确认项',
            'notificationCheckpoints': [
              {
                'checkpoint': '首轮同步完成',
                'description': '确认授课教师已收到完整修订信息，并可以立即执行。',
                'verify': '查看授课链路回执与页面状态更新',
              },
              {
                'checkpoint': '升级链路补发完成',
                'description': '确认负责人收到升级版风险结论与当前闭环状态。',
                'confirmation': '检查负责人链路回执和升级标签是否同步',
              },
            ],
          },
          {
            'type': 'notificationHandshakes',
            'title': '通知握手与确认回合',
            'notificationHandshakes': [
              {
                'handshake': '教师侧首次确认',
                'description': '授课教师确认已收到修订结论，并明确本节课按新版本执行。',
                'ack': '在课前同步页完成已读与执行确认',
              },
              {
                'handshake': '负责人侧补充确认',
                'description': '负责人确认升级判断已接收，并同意当前通知路径继续推进。',
                'reply': '在升级链路中回复继续推进或要求回收重发',
              },
            ],
          },
          {
            'type': 'notificationAcknowledgements',
            'title': '通知确认回执与已读状态',
            'notificationAcknowledgements': [
              {
                'acknowledgement': '授课教师回执',
                'description': '确认授课教师已经在课前页完成已读，并同步了本轮版本号。',
                'status': '已读并确认执行',
              },
              {
                'receipt': '负责人升级回执',
                'description': '确认负责人已看到升级判断摘要，并给出继续推进结论。',
                'receiptStatus': '已回执，允许继续推进',
              },
            ],
          },
          {
            'type': 'notificationEvidence',
            'title': '通知依据与佐证材料',
            'notificationEvidence': [
              {
                'evidence': '课堂修订单',
                'description': '本轮通知基于最新课堂修订单生成，结论与动作要求已锁定。',
                'proof': '修订单版本 v3.2 与发布记录一致',
              },
              {
                'source': '升级判断截图',
                'description': '负责人看到的升级版判断与教师端提醒内容保持同源。',
                'artifact': '升级判断卡截图与回执日志已归档',
              },
            ],
          },
          {
            'type': 'notificationRisks',
            'title': '通知风险与误发防线',
            'notificationRisks': [
              {
                'risk': '教师端收到过期版本',
                'description': '如果旧版摘要仍在缓存页展示，授课教师可能按旧动作执行。',
                'mitigation': '发前校验版本号并强制刷新已读页',
              },
              {
                'label': '负责人链路遗漏升级标签',
                'summary': '升级判断虽已发送，但负责人侧若缺升级标签，可能误判优先级。',
                'guardrail': '升级通知必须绑定红色风险标签和当前状态卡',
              },
            ],
          },
          {
            'type': 'notificationRecoveries',
            'title': '通知补救路径与恢复动作',
            'notificationRecoveries': [
              {
                'recovery': '强制重发教师链路',
                'description': '若教师端版本号未刷新，则立即作废旧摘要并重发最新通知包。',
                'trigger': '发现教师端回执版本落后于当前发布版本',
              },
              {
                'action': '补发负责人升级摘要',
                'summary': '若负责人未收到升级标签，则补发升级版判断卡与当前闭环状态。',
                'when': '负责人侧回执缺失或未带升级标签',
              },
            ],
          },
          {
            'type': 'notificationImpacts',
            'title': '通知影响面与波及对象',
            'notificationImpacts': [
              {
                'impact': '课堂执行路径调整',
                'description': '授课教师需要立刻改用新版讲解顺序与板书提示。',
                'affected': '授课教师、跟课教研',
              },
              {
                'scope': '升级判断同步',
                'summary': '负责人需要按新风险等级重新判断是否继续沿现有链路推进。',
                'audience': '负责人、教务协调人',
              },
            ],
          },
          {
            'type': 'notificationDependenciesMap',
            'title': '通知依赖图与前置链路',
            'notificationDependenciesMap': [
              {
                'dependency': '教师端执行确认',
                'description': '负责校验授课教师是否收到并确认执行新版通知。',
                'requires': '教师侧已读回执、当前版本号同步完成',
              },
              {
                'node': '负责人升级判断',
                'summary': '只有负责人看到升级判断卡并回执后，后续升级提醒才允许继续发送。',
                'dependsOn': '升级标签同步、负责人回执、闭环状态卡更新',
              },
            ],
          },
          {
            'type': 'notificationOwnersMap',
            'title': '通知负责人映射与接手边界',
            'notificationOwnersMap': [
              {
                'ownerMap': '教师执行链路',
                'description': '负责接收课堂执行版通知，并在课前页完成已读与执行确认。',
                'owner': '授课教师',
              },
              {
                'role': '升级判断链路',
                'summary': '负责在风险升级时确认是否继续沿当前通知路径推进。',
                'assignee': '负责人 / 教务协调人',
              },
            ],
          },
          {
            'type': 'notificationDecisionsLog',
            'title': '通知决策日志与处理结论',
            'notificationDecisionsLog': [
              {
                'decision': '首轮课堂通知继续下发',
                'description': '确认教师端已同步新版摘要后，继续沿课堂执行链路发出通知。',
                'result': '继续推进',
              },
              {
                'entry': '升级判断补发负责人链路',
                'summary': '负责人侧缺失升级标签，先补发升级摘要，再等待负责人回执。',
                'status': '补发后待确认',
              },
            ],
          },
          {
            'type': 'notificationStateChanges',
            'title': '通知状态变化与当前进度',
            'notificationStateChanges': [
              {
                'stateChange': '教师侧同步完成',
                'description': '教师端已经完成新版通知的已读与执行确认。',
                'change': '待发送 -> 已送达并确认',
              },
              {
                'step': '负责人升级链路',
                'summary': '负责人侧仍在等待升级判断回执，当前链路尚未完全闭环。',
                'transition': '已补发 -> 待负责人确认',
              },
            ],
          },
          {
            'type': 'notificationReadiness',
            'title': '通知就绪度与发前判断',
            'notificationReadiness': [
              {
                'readiness': '教师链路发前检查',
                'description': '确认授课教师端已切到最新版页面，并具备执行新版摘要的前提。',
                'status': '已满足，可直接下发',
              },
              {
                'checkpoint': '升级链路补发条件',
                'summary': '负责人侧只有在升级标签和当前闭环状态同步完成后才允许补发。',
                'decision': '部分满足，需先同步升级标签',
              },
            ],
          },
          {
            'type': 'notificationCoverageChecks',
            'title': '通知覆盖校验与漏发检查',
            'notificationCoverageChecks': [
              {
                'coverageCheck': '教师执行链路覆盖',
                'description': '确认所有授课教师都已收到新版摘要，没有遗漏旧课表关联班级。',
                'check': '已覆盖全部授课教师与跟课教研',
              },
              {
                'scope': '负责人升级提醒覆盖',
                'summary': '确认所有需要升级判断的负责人都收到补发链路，没有遗漏代理负责人。',
                'result': '仍缺 1 个代理负责人回执',
              },
            ],
          },
          {
            'type': 'notificationConfirmations',
            'title': '通知确认节点与收口标志',
            'notificationConfirmations': [
              {
                'confirmation': '教师侧执行确认',
                'description': '确认教师端已读并执行新版摘要，本轮课堂执行链路可以视为闭环。',
                'signoff': '教师已确认执行',
              },
              {
                'checkpoint': '负责人升级确认',
                'summary': '确认负责人看到升级版判断卡并给出最终处理结论。',
                'closure': '负责人已回执，升级链路收口',
              },
            ],
          },
          {
            'type': 'notificationClosures',
            'title': '通知闭环结果与收尾动作',
            'notificationClosures': [
              {
                'closure': '教师链路闭环完成',
                'description': '教师端已确认执行，新版通知在课堂侧已完成本轮闭环。',
                'followUp': '保留课堂执行记录，进入复盘队列',
              },
              {
                'result': '升级链路待最终归档',
                'summary': '负责人已回执，但仍需把升级判断和回执日志归档到闭环记录。',
                'handoff': '交由教务协调人补齐归档与留痕',
              },
            ],
          },
          {
            'type': 'notificationExceptionsLog',
            'title': '通知例外记录与人工介入',
            'notificationExceptionsLog': [
              {
                'exception': '教师端旧版缓存未失效',
                'description': '个别教师端仍展示旧版摘要，需要人工清缓存并补发最新通知。',
                'handling': '教务协调人已介入，补发新版通知包',
              },
              {
                'entry': '负责人回执超时',
                'summary': '负责人在规定时窗内未回执，自动流程暂停并进入人工跟进。',
                'manualAction': '转人工电话确认并补录回执结论',
              },
            ],
          },
          {
            'type': 'notificationEscalationChecks',
            'title': '通知升级校验与转交门槛',
            'notificationEscalationChecks': [
              {
                'escalationCheck': '负责人升级判断门槛',
                'description': '只有风险标签、当前状态卡和负责人回执链路全部可用时，才允许继续升级转交。',
                'threshold': '三项前置全部满足',
              },
              {
                'checkpoint': '人工接手触发条件',
                'summary': '若负责人链路连续超时或标签缺失，则自动停止继续下发并转人工接手。',
                'condition': '连续 2 次超时或升级标签缺失',
              },
            ],
          },
          {
            'type': 'notificationRoutingDecisions',
            'title': '通知路由决策与分发选择',
            'notificationRoutingDecisions': [
              {
                'decision': '教师执行链路优先',
                'description': '课堂执行类变更优先直接发到授课教师链路，减少中间转发。',
                'channel': '授课教师 / 跟课教研',
              },
              {
                'route': '升级判断改走负责人链路',
                'summary': '涉及风险判断的变更直接发负责人链路，不再继续沿教师链路补充说明。',
                'path': '负责人 / 教务协调人',
              },
            ],
          },
          {
            'type': 'notificationDeliveryProofs',
            'title': '通知送达凭证与触达确认',
            'notificationDeliveryProofs': [
              {
                'proof': '教师链路送达凭证',
                'description': '系统已记录教师端卡片展开、已读时间与页面停留时长，能确认课堂执行通知已被实际查看。',
                'receipt': '已读并停留 42 秒',
              },
              {
                'evidence': '负责人链路回执截图',
                'summary': '负责人链路补充了签收截图和确认备注，可作为后续升级结论的留痕凭证。',
                'confirmation': '截图已归档 / 备注已同步',
              },
            ],
          },
          {
            'title': '通知补充留痕',
            'notificationReceiptNotes': [
              {
                'label': '教师端截图已上传',
                'value': '跟课教师补充了课堂卡片截图，能用于复核发送时点与展示状态。',
              },
              {
                'label': '负责人备注已补录',
                'value': '负责人在人工跟进后补写了处理备注，后续复盘可以直接引用。',
              },
            ],
          },
          {
            'title': '补充执行回看',
            'deliveryReadbacks': [
              {
                'label': '教师端补记',
                'value': '补充说明已在课堂结束后 5 分钟内写回，便于后续复盘。',
              },
              {
                'label': '负责人确认',
                'value': '负责人已在回看卡中补充确认结论，后续不再重复追问。',
              },
            ],
          },
          {
            'type': 'agenda',
            'title': '议程与安排',
            'agenda': [
              {
                'title': '识图热身',
                'time': '3 分钟',
                'description': '先完成图形关系辨认，确认相似判定入口。',
              },
              {
                'title': '比例推导',
                'time': '6 分钟',
                'description': '组织边比链条并板演关键推理步骤。',
              },
            ],
          },
          {
            'type': 'corrections',
            'title': '纠错与修正',
            'corrections': [
              {
                'title': '比例式顺序颠倒时先口头校正',
                'text': '如果学生把对应边顺序写反，先让他口头重述对应关系，再回到板书修正比例式。',
              },
              {
                'title': '跳结论时补上中间依据',
                'text': '一旦学生直接写出角度或长度结论，立即追问中间依据，再补回完整推理链。',
              },
            ],
          },
          {
            'type': 'facets',
            'title': '分析维度',
            'facets': [
              {
                'title': '识图维度',
                'text': '先看学生能否稳定识别对应角与对应边，而不是只会套比例式。',
              },
              {
                'title': '推理维度',
                'text': '再看学生能否把比例关系与最终结论之间的桥梁说完整。',
              },
            ],
          },
          {
            'type': 'dialogue',
            'title': '对话与讨论',
            'dialogue': [
              {
                'speaker': '教师追问',
                'text': '你这里为什么先写这一组对应边，而不是另一组？',
              },
              {
                'speaker': '学生回应',
                'text': '因为这一组边先由对应角确定下来，后面比例式就不会乱。',
              },
            ],
          },
          {
            'type': 'observations',
            'title': '观察与发现',
            'observations': [
              {
                'title': '会先稳住对应关系',
                'text': '一旦学生开始先说对应角再写比例，后续步骤出错率会明显下降。',
              },
              {
                'title': '遗漏中间依据时最易跳步',
                'text': '如果中间依据没有被说出来，学生通常会直接跳到最后结论。',
              },
            ],
          },
          {
            'type': 'actions',
            'title': '操作动作',
            'actions': [
              {
                'title': '先圈出对应角',
                'text': '板书前先在图上标出对应角，让比例式的后续表达有稳定锚点。',
              },
              {
                'title': '再写完整比例链',
                'text': '把比例关系完整写出来后，再引导学生推出长度或角度结论。',
              },
            ],
          },
          {
            'type': 'transitions',
            'title': '过渡与衔接',
            'transitions': [
              {
                'title': '从识图过渡到比例',
                'text': '先确认对应角与对应边，再自然切到比例式书写，避免学生突然断层。',
              },
              {
                'title': '从比例过渡到结论',
                'text': '比例式写完后，用一句中间依据把学生带到长度或角度结论，而不是直接跳结果。',
              },
            ],
          },
          {
            'type': 'tabs',
            'title': '讲评切面',
            'tabs': [
              {
                'tab': '识图',
                'content': [
                  {
                    'type': 'text',
                    'text': '优先检查学生是否正确锁定对应角与对应边。',
                  },
                ],
              },
              {
                'tab': '转化',
                'content': [
                  {
                    'type': 'text',
                    'text': '比例式写完后，再引导学生说明如何过渡到角度结论。',
                  },
                ],
              },
            ],
          },
          {
            'type': 'comparison',
            'title': '讲评前后对比',
            'comparison': [
              {
                'title': '调整前',
                'content': [
                  {
                    'type': 'text',
                    'text': '学生容易先套比例式，再回头补对应关系，过程容易错位。',
                  },
                ],
              },
              {
                'title': '调整后',
                'content': [
                  {
                    'type': 'text',
                    'text': '先口头确认对应角，再统一写比例模板，比例顺序和后续推理都更稳定。',
                  },
                ],
              },
            ],
          },
          {
            'type': 'accordion',
            'title': '追问展开',
            'details': [
              {
                'summary': '如果学生找错对应边怎么办？',
                'content': [
                  {
                    'type': 'text',
                    'text': '先回到对应角，再让学生用语言解释“哪两条边是被这两个角夹着的”。',
                  },
                ],
              },
              {
                'summary': '什么时候需要直接给板书模板？',
                'content': [
                  {
                    'type': 'text',
                    'text': '当全班在比例式顺序上连续出错时，直接给模板更有效。',
                  },
                ],
              },
            ],
          },
        ],
        stemText:
            r'已知 \triangle ABC \sim \triangle DEF，求证对应边比相等，并进一步判断相关角的数量关系。',
        analysisText: '先识别相似条件，再从对应角与对应边切入，最后把比例关系转成可计算的几何量。',
        solutionText: '由已知可得两三角形对应角相等、对应边成比例；再结合角平分线或圆周角性质，可把结论逐步转化为边比和角度关系。',
        referenceAnswerText: '对应边成比例，再结合对应角相等可进一步推出相关角度关系。',
        scoringPointsText: '评分点（4 分）：说明对应角相等。评分点（6 分）：完整写出对应边成比例并得出结论。',
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
          {
            'type': 'table',
            'label': '参数讨论表',
            'rows': [
              ['条件', '图像特征', '最值判断'],
              [r'$a > 0$', '开口向上', '顶点为最小值'],
              [r'$a < 0$', '开口向下', '顶点为最大值'],
            ],
          },
        ],
        analysisBlocks: [
          {'type': 'text', 'text': '核心是把解析式、顶点式与图像特征统一起来看。'}
        ],
        solutionBlocks: [
          {'type': 'text', 'text': '将一般式配方得到顶点式。'},
          {'type': 'text', 'text': '利用对称轴和顶点纵坐标公式判断最值。'}
        ],
        referenceAnswerBlocks: [
          {'type': 'text', 'text': '先配方得到顶点式，再利用对称轴与顶点纵坐标判断最值。'},
          {'type': 'latex', 'text': r'x=-\frac{b}{2a}'},
        ],
        scoringPointBlocks: [
          {'type': 'text', 'text': '评分点（5 分）：正确配方得到顶点式。'},
          {'type': 'text', 'text': '评分点（5 分）：利用对称轴和顶点判断最值。'},
        ],
        commentaryBlocks: [
          {'type': 'text', 'text': '适合和图像性质、根与系数关系放在同一专题卷中。'}
        ],
        sourceBlocks: [
          {'type': 'text', 'text': '2025-03 九下阶段性复习'},
          {'type': 'text', 'text': '二次函数'},
        ],
        stemText: r'设抛物线 y=ax^2+bx+c 与 x 轴交于两点，讨论顶点坐标与最值，并分析参数变化对图像的影响。',
        analysisText: '核心是把函数解析式、顶点式与图像特征统一起来看，先抓开口方向，再抓对称轴和顶点。',
        solutionText:
            '将一般式配方得到顶点式，利用对称轴 x=-b/2a 和顶点纵坐标公式判断最值，再根据与 x 轴交点情况讨论参数范围。',
        referenceAnswerText: '先配方得到顶点式，再利用对称轴和顶点纵坐标判断最值。',
        scoringPointsText: '评分点（5 分）：正确配方得到顶点式。评分点（5 分）：利用对称轴和顶点判断最值。',
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
          {
            'type': 'table',
            'label': '实验记录表',
            'rows': [
              ['组别', '排开液体体积', '测得浮力'],
              ['A', '20 mL', '0.2 N'],
              ['B', '40 mL', '0.4 N'],
              ['C', '60 mL', '0.6 N'],
            ],
          },
        ],
        analysisBlocks: [
          {'type': 'text', 'text': '先读实验变量，再看控制变量与因变量。'}
        ],
        solutionBlocks: [
          {'type': 'text', 'text': '比较不同组数据可知，排开液体体积越大，测得浮力越大。'},
          {'type': 'text', 'text': '若数据偏差明显，则从读数和液体残留分析误差。'}
        ],
        referenceAnswerBlocks: [
          {'type': 'text', 'text': '实验数据表明：排开液体体积越大，浮力越大。'},
          {'type': 'text', 'text': '误差可从读数、液体残留和器材误差分析。'},
        ],
        scoringPointBlocks: [
          {'type': 'text', 'text': '评分点（4 分）：正确读出数据趋势。'},
          {'type': 'text', 'text': '评分点（4 分）：说明至少一种误差来源。'},
        ],
        commentaryBlocks: [
          {'type': 'text', 'text': '适合实验探究讲义，配合表格与结论归纳框。'}
        ],
        sourceBlocks: [
          {'type': 'text', 'text': '2024-11 实验探究训练'},
          {'type': 'text', 'text': '浮力'},
        ],
        stemText: r'根据实验记录表分析排开液体体积与浮力大小的关系，并说明误差可能来源。',
        analysisText: '这类题先读实验变量，再看控制变量与因变量，最后用数据趋势支撑结论。',
        solutionText:
            '比较不同组数据可知，排开液体体积越大，测得浮力越大；若数据偏差明显，则要从弹簧测力计读数、液体残留等角度分析误差。',
        referenceAnswerText: '排开液体体积越大，浮力越大；误差可从读数和液体残留分析。',
        scoringPointsText: '评分点（4 分）：正确读出数据趋势。评分点（4 分）：说明至少一种误差来源。',
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
      hasStructuredPreview: false,
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

  Future<DocumentSummary> renameDocument({
    required String documentId,
    required String name,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final index =
        _documents.indexWhere((document) => document.id == documentId);
    if (index < 0) {
      throw const HttpJsonException(
          statusCode: 404, message: 'Document not found');
    }

    final current = _documents[index];
    final renamed = current.copyWith(name: name);
    _documents[index] = renamed;
    return renamed;
  }

  Future<void> removeDocument(String documentId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _documents.removeWhere((document) => document.id == documentId);
    _documentItems.remove(documentId);
    _exportJobs.removeWhere((job) => job.documentId == documentId);
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
      subject: question.subject,
      stage: question.stage,
      grade: question.grade,
      textbook: question.textbook,
      chapter: question.chapter,
      sourceQuestionId: question.id,
      previewBlocks: question.previewBlocks.isNotEmpty
          ? question.previewBlocks
          : [
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

  Future<LayoutElementSummary> createLayoutElement({
    required String name,
    required String description,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final trimmedName = name.trim();
    final trimmedDescription = description.trim();
    final layoutElement = LayoutElementSummary(
      id: 'layout-${DateTime.now().millisecondsSinceEpoch}',
      name: trimmedName.isEmpty ? '未命名排版元素' : trimmedName,
      description: trimmedDescription,
      previewBlocks: <Map<String, dynamic>>[
        <String, dynamic>{'type': 'text', 'text': trimmedName},
        if (trimmedDescription.isNotEmpty)
          <String, dynamic>{'type': 'text', 'text': trimmedDescription},
      ],
    );
    _layoutElements.insert(0, layoutElement);
    return layoutElement;
  }

  Future<LayoutElementSummary> updateLayoutElement({
    required String layoutElementId,
    required String name,
    required String description,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final index =
        _layoutElements.indexWhere((item) => item.id == layoutElementId);
    final updated = LayoutElementSummary(
      id: layoutElementId,
      name: name.trim().isEmpty ? '未命名排版元素' : name.trim(),
      description: description.trim(),
      previewBlocks: <Map<String, dynamic>>[
        <String, dynamic>{'type': 'text', 'text': name.trim()},
        if (description.trim().isNotEmpty)
          <String, dynamic>{'type': 'text', 'text': description.trim()},
      ],
    );
    if (index >= 0) {
      _layoutElements[index] = updated;
    } else {
      _layoutElements.insert(0, updated);
    }
    for (final entry in _documentItems.entries) {
      final items = entry.value;
      for (var i = 0; i < items.length; i += 1) {
        final item = items[i];
        if (item.sourceLayoutElementId == layoutElementId) {
          items[i] = DocumentItemSummary(
            id: item.id,
            kind: item.kind,
            title: updated.name,
            detail: updated.description,
            subject: item.subject,
            stage: item.stage,
            grade: item.grade,
            textbook: item.textbook,
            chapter: item.chapter,
            sourceQuestionId: item.sourceQuestionId,
            sourceLayoutElementId: layoutElementId,
            previewBlocks: updated.previewBlocks,
          );
        }
      }
    }
    return updated;
  }

  Future<void> removeLayoutElement(String layoutElementId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final inUse = _documentItems.values.any(
      (items) =>
          items.any((item) => item.sourceLayoutElementId == layoutElementId),
    );
    if (inUse) {
      throw const HttpJsonException(
        statusCode: 400,
        message: 'LayoutElement is still used by a document',
      );
    }
    _layoutElements.removeWhere((item) => item.id == layoutElementId);
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
      sourceLayoutElementId: layoutElement.id,
      previewBlocks: layoutElement.previewBlocks.isNotEmpty
          ? layoutElement.previewBlocks
          : [
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
    final documentIndex =
        _documents.indexWhere((item) => item.id == documentId);
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
      hasStructuredPreview: items.isNotEmpty,
      previewBlocks: _buildDocumentPreviewBlocks(documentId, document),
    );
  }

  List<Map<String, dynamic>> _buildDocumentPreviewBlocks(
    String documentId,
    DocumentSummary document,
  ) {
    final items = _documentItems[documentId] ?? const <DocumentItemSummary>[];
    if (items.isNotEmpty) {
      final previewItems = items.take(2).toList(growable: false);
      final blocks = <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'text',
          'text': document.kind == 'paper' ? '试卷内容预览' : '讲义内容预览',
        },
      ];
      for (final item in previewItems) {
        blocks.add(
          <String, dynamic>{
            'type': 'text',
            'text': item.kind == 'question'
                ? '题目项 · ${item.title}'
                : '排版元素 · ${item.title}',
          },
        );
        if (item.previewBlocks.isNotEmpty) {
          blocks.addAll(item.previewBlocks.take(2));
          continue;
        }
        if (item.detail.trim().isNotEmpty) {
          blocks.add(
            <String, dynamic>{
              'type': 'text',
              'text': item.detail.trim(),
            },
          );
        }
      }
      if (items.length > previewItems.length) {
        blocks.add(
          <String, dynamic>{
            'type': 'text',
            'text': '其余 ${items.length - previewItems.length} 项内容已收起',
          },
        );
      }
      return blocks;
    }

    return <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'text',
        'text': document.kind == 'paper' ? '试卷内容预览' : '讲义内容预览',
      },
      <String, dynamic>{
        'type': 'text',
        'text': '当前还没有文档项，可以先加入题目或排版元素开始编排。',
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

    final documentIndex =
        _documents.indexWhere((item) => item.id == documentId);
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
        hasStructuredPreview: current.hasStructuredPreview,
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
        hasStructuredPreview: current.hasStructuredPreview,
        previewBlocks: current.previewBlocks,
      );
    }

    return job;
  }

  Future<ExportJobSummary> cancelExportJob({
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
      status: 'canceled',
      updatedAtLabel: '刚刚取消',
    );
    _exportJobs[jobIndex] = next;

    final documentId = current.documentId;
    if (documentId != null && documentId.isNotEmpty) {
      final documentIndex =
          _documents.indexWhere((item) => item.id == documentId);
      if (documentIndex >= 0) {
        final document = _documents[documentIndex];
        _documents[documentIndex] = DocumentSummary(
          id: document.id,
          name: document.name,
          kind: document.kind,
          questionCount: document.questionCount,
          layoutCount: document.layoutCount,
          latestExportStatus: 'canceled',
          latestExportJobId: current.id,
          hasStructuredPreview: document.hasStructuredPreview,
          previewBlocks: document.previewBlocks,
        );
      }
    }

    return next;
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
      final documentIndex =
          _documents.indexWhere((item) => item.id == documentId);
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
          hasStructuredPreview: document.hasStructuredPreview,
          previewBlocks: document.previewBlocks,
        );
      }
    }

    return next;
  }

  Future<ExportJobSummary?> getExportJob(String jobId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final index = _exportJobs.indexWhere((item) => item.id == jobId);
    if (index < 0) {
      return null;
    }
    return _exportJobs[index];
  }

  Future<List<ExportJobSummary>> listExportJobs() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));

    return List<ExportJobSummary>.from(_exportJobs);
  }
}
