import '../api/shiti_api_client.dart';
import '../config/app_config.dart';
import '../models/auth_session.dart';
import '../models/tenant_summary.dart';
import '../network/http_json_client.dart';
import '../repositories/class_repository.dart';
import '../repositories/document_repository.dart';
import '../repositories/lesson_repository.dart';
import '../repositories/question_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/student_repository.dart';
import '../repositories/taxonomy_repository.dart';
import 'session_persistence.dart';
import 'package:flutter/material.dart';
import '../../router/app_router.dart';

class AppServices {
  AppServices._() : apiClient = const ShiTiApiClient() {
    if (AppConfig.useMockData) {
      sessionRepository = FakeSessionRepository(apiClient);
      questionRepository = FakeQuestionRepository(apiClient);
      classRepository = FakeClassRepository(apiClient);
      documentRepository = FakeDocumentRepository(apiClient);
      lessonRepository = FakeLessonRepository(apiClient);
      studentRepository = FakeStudentRepository(apiClient);
      taxonomyRepository = FakeTaxonomyRepository(apiClient);
      return;
    }

    final httpClient = HttpJsonClient(
      baseUrl: AppConfig.apiBaseUrl,
      defaultHeadersBuilder: _buildDefaultHeaders,
      onUnauthorized: handleUnauthorized,
    );
    sessionRepository = RemoteSessionRepository(
      httpClient,
      onSessionUpdated: setSession,
      currentSessionProvider: () => _session,
    );
    questionRepository = RemoteQuestionRepository(httpClient);
    classRepository = RemoteClassRepository(httpClient);
    documentRepository = RemoteDocumentRepository(httpClient);
    lessonRepository = RemoteLessonRepository(httpClient);
    studentRepository = RemoteStudentRepository(httpClient);
    taxonomyRepository = RemoteTaxonomyRepository(httpClient);
  }

  static final AppServices instance = AppServices._();

  final ShiTiApiClient apiClient;
  late final SessionRepository sessionRepository;
  late final QuestionRepository questionRepository;
  late final ClassRepository classRepository;
  late final DocumentRepository documentRepository;
  late final LessonRepository lessonRepository;
  late final StudentRepository studentRepository;
  late final TaxonomyRepository taxonomyRepository;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  SessionPersistence? _sessionPersistence;
  AuthSession? _session;
  TenantSummary? _activeTenant;

  AuthSession? get session => _session;
  TenantSummary? get activeTenant => _activeTenant;
  bool get isMockMode => AppConfig.useMockData;

  Future<void> initialize() async {
    _sessionPersistence = await SessionPersistence.create();
    _session = _sessionPersistence?.loadSession();
    _activeTenant = _sessionPersistence?.loadActiveTenant();
  }

  void setSession(AuthSession session) {
    _session = session;
    _sessionPersistence?.saveSession(session);
  }

  void clearSession() {
    _session = null;
    _activeTenant = null;
    _sessionPersistence?.clear();
  }

  void handleUnauthorized() {
    clearSession();
    final navigator = navigatorKey.currentState;
    final context = navigatorKey.currentContext;
    if (navigator == null || context == null) {
      return;
    }
    navigator.pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('登录状态已失效，请重新登录')),
    );
  }

  void setActiveTenant(TenantSummary tenant) {
    _activeTenant = tenant;
    _sessionPersistence?.saveActiveTenant(tenant);
  }

  Map<String, String> _buildDefaultHeaders() {
    return <String, String>{
      if ((_session?.accessToken ?? '').isNotEmpty)
        'Authorization': 'Bearer ${_session!.accessToken}',
      if ((_activeTenant?.code ?? '').isNotEmpty)
        'x-tenant-code': _activeTenant!.code,
    };
  }
}
