import '../api/shiti_api_client.dart';
import '../models/auth_session.dart';
import '../models/tenant_summary.dart';
import '../network/http_json_client.dart';

abstract class SessionRepository {
  Future<AuthSession> login({
    required String username,
    required String password,
  });

  Future<AuthSession> register({
    required String username,
    required String password,
  });

  Future<List<TenantSummary>> listTenants();

  Future<TenantSummary?> resolveTenant(String tenantCode);

  Future<TenantSummary> createTenant({
    required String code,
    required String name,
  });
}

class FakeSessionRepository implements SessionRepository {
  const FakeSessionRepository(this._apiClient);

  final ShiTiApiClient _apiClient;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) {
    return _apiClient.login(username: username, password: password);
  }

  @override
  Future<AuthSession> register({
    required String username,
    required String password,
  }) {
    return _apiClient.register(username: username, password: password);
  }

  @override
  Future<List<TenantSummary>> listTenants() {
    return _apiClient.listTenants();
  }

  @override
  Future<TenantSummary?> resolveTenant(String tenantCode) async {
    final tenants = await listTenants();
    for (final tenant in tenants) {
      if (tenant.code == tenantCode) {
        return tenant;
      }
    }
    return null;
  }

  @override
  Future<TenantSummary> createTenant({
    required String code,
    required String name,
  }) {
    return _apiClient.createTenant(code: code, name: name);
  }
}

class RemoteSessionRepository implements SessionRepository {
  const RemoteSessionRepository(
    this._client, {
    this.onSessionUpdated,
  });

  final HttpJsonClient _client;
  final void Function(AuthSession session)? onSessionUpdated;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final object = await _client.postObject(
      '/auth/login',
      body: <String, dynamic>{
        'username': username,
        'password': password,
      },
    );

    final session = AuthSession(
      userId: (object['userId'] ?? '').toString(),
      username: (object['username'] ?? username).toString(),
      accessLevel: (object['accessLevel'] ?? 'member').toString(),
      accessToken: (object['accessToken'] ?? '').toString(),
      tokenPreview: (object['accessToken'] ?? 'remote-token').toString(),
    );
    onSessionUpdated?.call(session);
    return session;
  }

  @override
  Future<AuthSession> register({
    required String username,
    required String password,
  }) async {
    final object = await _client.postObject(
      '/auth/register',
      body: <String, dynamic>{
        'username': username,
        'password': password,
      },
    );

    final session = AuthSession(
      userId: (object['userId'] ?? '').toString(),
      username: (object['username'] ?? username).toString(),
      accessLevel: (object['accessLevel'] ?? 'member').toString(),
      accessToken: (object['accessToken'] ?? '').toString(),
      tokenPreview: (object['accessToken'] ?? 'remote-token').toString(),
    );
    onSessionUpdated?.call(session);
    return session;
  }

  @override
  Future<List<TenantSummary>> listTenants() async {
    return const <TenantSummary>[];
  }

  @override
  Future<TenantSummary?> resolveTenant(String tenantCode) async {
    final object = await _client.getObject(
      '/tenants/resolve',
      headers: <String, String>{'x-tenant-code': tenantCode},
    );
    final tenant = object['tenant'];
    if (tenant is! Map<String, dynamic>) {
      return null;
    }
    return TenantSummary(
      id: (tenant['id'] ?? '').toString(),
      code: (tenant['code'] ?? tenantCode).toString(),
      name: (tenant['name'] ?? '未命名租户').toString(),
      role: 'member',
    );
  }

  @override
  Future<TenantSummary> createTenant({
    required String code,
    required String name,
  }) async {
    final object = await _client.postObject(
      '/tenants',
      body: <String, dynamic>{
        'code': code,
        'name': name,
      },
    );
    final tenant = object['tenant'];
    if (tenant is Map<String, dynamic>) {
      return TenantSummary(
        id: (tenant['id'] ?? '').toString(),
        code: (tenant['code'] ?? code).toString(),
        name: (tenant['name'] ?? name).toString(),
        role: 'owner',
      );
    }
    return TenantSummary(
      id: '',
      code: code,
      name: name,
      role: 'owner',
    );
  }
}
