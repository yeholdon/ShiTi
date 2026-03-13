import '../api/shiti_api_client.dart';
import '../config/app_config.dart';
import '../models/auth_session.dart';
import '../models/tenant_summary.dart';
import '../network/http_json_client.dart';
import '../repositories/document_repository.dart';
import '../repositories/question_repository.dart';
import '../repositories/session_repository.dart';

class AppServices {
  AppServices._() : apiClient = const ShiTiApiClient() {
    if (AppConfig.useMockData) {
      sessionRepository = FakeSessionRepository(apiClient);
      questionRepository = FakeQuestionRepository(apiClient);
      documentRepository = FakeDocumentRepository(apiClient);
      return;
    }

    final httpClient = HttpJsonClient(
      baseUrl: AppConfig.apiBaseUrl,
      defaultHeadersBuilder: _buildDefaultHeaders,
    );
    sessionRepository = RemoteSessionRepository(
      httpClient,
      onSessionUpdated: setSession,
    );
    questionRepository = RemoteQuestionRepository(httpClient);
    documentRepository = RemoteDocumentRepository(httpClient);
  }

  static final AppServices instance = AppServices._();

  final ShiTiApiClient apiClient;
  late final SessionRepository sessionRepository;
  late final QuestionRepository questionRepository;
  late final DocumentRepository documentRepository;
  AuthSession? _session;
  TenantSummary? _activeTenant;

  AuthSession? get session => _session;
  TenantSummary? get activeTenant => _activeTenant;
  bool get isMockMode => AppConfig.useMockData;

  void setSession(AuthSession session) {
    _session = session;
  }

  void setActiveTenant(TenantSummary tenant) {
    _activeTenant = tenant;
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
