import '../api/shiti_api_client.dart';
import '../models/auth_session.dart';
import '../models/password_reset_request_result.dart';
import '../models/tenant_member_audit_event.dart';
import '../models/tenant_member_summary.dart';
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

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<PasswordResetRequestResult> requestPasswordReset({
    required String username,
    String deliveryMode = 'preview',
  });

  Future<void> resetPassword({
    required String username,
    required String resetToken,
    required String newPassword,
  });

  Future<void> logout();

  Future<List<TenantSummary>> listTenants();

  Future<TenantSummary?> resolveTenant(String tenantCode);

  Future<TenantSummary> createTenant({
    required String code,
    required String name,
  });

  Future<List<TenantMemberSummary>> listTenantMembers({
    required String tenantCode,
  });

  Future<TenantMemberSummary> updateTenantMemberRole({
    required String tenantCode,
    required String memberId,
    required String role,
  });

  Future<TenantMemberSummary> addTenantMember({
    required String tenantCode,
    required String username,
    required String role,
    String status = 'active',
  });

  Future<TenantMemberSummary> joinCurrentTenant({
    required String tenantCode,
    required String role,
    String status = 'active',
  });

  Future<TenantMemberSummary> updateTenantMemberStatus({
    required String tenantCode,
    required String memberId,
    required String status,
  });

  Future<TenantMemberSummary> resendTenantMemberInvite({
    required String tenantCode,
    required String memberId,
  });

  Future<void> removeTenantMember({
    required String tenantCode,
    required String memberId,
  });

  Future<List<TenantMemberAuditEvent>> listTenantMemberAuditEvents({
    required String tenantCode,
    required String userId,
    int limit = 5,
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
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _apiClient.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  @override
  Future<PasswordResetRequestResult> requestPasswordReset({
    required String username,
    String deliveryMode = 'preview',
  }) {
    return _apiClient.requestPasswordReset(
      username: username,
      deliveryMode: deliveryMode,
    );
  }

  @override
  Future<void> resetPassword({
    required String username,
    required String resetToken,
    required String newPassword,
  }) {
    return _apiClient.resetPassword(
      username: username,
      resetToken: resetToken,
      newPassword: newPassword,
    );
  }

  @override
  Future<void> logout() {
    return _apiClient.logout();
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

  @override
  Future<List<TenantMemberSummary>> listTenantMembers({
    required String tenantCode,
  }) async {
    return _apiClient.listTenantMembers(tenantCode: tenantCode);
  }

  @override
  Future<TenantMemberSummary> updateTenantMemberRole({
    required String tenantCode,
    required String memberId,
    required String role,
  }) async {
    return _apiClient.updateTenantMemberRole(
      tenantCode: tenantCode,
      memberId: memberId,
      role: role,
    );
  }

  @override
  Future<TenantMemberSummary> addTenantMember({
    required String tenantCode,
    required String username,
    required String role,
    String status = 'active',
  }) async {
    return _apiClient.addTenantMember(
      tenantCode: tenantCode,
      username: username,
      role: role,
      status: status,
    );
  }

  @override
  Future<TenantMemberSummary> joinCurrentTenant({
    required String tenantCode,
    required String role,
    String status = 'active',
  }) async {
    return _apiClient.joinCurrentTenant(
      tenantCode: tenantCode,
      role: role,
      status: status,
    );
  }

  @override
  Future<TenantMemberSummary> updateTenantMemberStatus({
    required String tenantCode,
    required String memberId,
    required String status,
  }) async {
    return _apiClient.updateTenantMemberStatus(
      tenantCode: tenantCode,
      memberId: memberId,
      status: status,
    );
  }

  @override
  Future<TenantMemberSummary> resendTenantMemberInvite({
    required String tenantCode,
    required String memberId,
  }) async {
    return _apiClient.resendTenantMemberInvite(
      tenantCode: tenantCode,
      memberId: memberId,
    );
  }

  @override
  Future<void> removeTenantMember({
    required String tenantCode,
    required String memberId,
  }) async {
    await _apiClient.removeTenantMember(
      tenantCode: tenantCode,
      memberId: memberId,
    );
  }

  @override
  Future<List<TenantMemberAuditEvent>> listTenantMemberAuditEvents({
    required String tenantCode,
    required String userId,
    int limit = 5,
  }) async {
    return _apiClient.listTenantMemberAuditEvents(
      tenantCode: tenantCode,
      userId: userId,
      limit: limit,
    );
  }
}

class RemoteSessionRepository implements SessionRepository {
  const RemoteSessionRepository(
    this._client, {
    this.onSessionUpdated,
    this.currentSessionProvider,
  });

  final HttpJsonClient _client;
  final void Function(AuthSession session)? onSessionUpdated;
  final AuthSession? Function()? currentSessionProvider;

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
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.postObject(
      '/auth/change-password',
      body: <String, dynamic>{
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  @override
  Future<PasswordResetRequestResult> requestPasswordReset({
    required String username,
    String deliveryMode = 'preview',
  }) async {
    final object = await _client.postObject(
      '/auth/request-password-reset',
      body: <String, dynamic>{
        'username': username,
        'deliveryMode': deliveryMode,
      },
    );
    return PasswordResetRequestResult(
      deliveryMode: (object['deliveryMode'] ?? deliveryMode).toString(),
      deliveryTransport: object['deliveryTransport']?.toString(),
      deliveryTargetHint: object['deliveryTargetHint']?.toString(),
      requestId: object['requestId']?.toString(),
      resetTokenPreview: object['resetTokenPreview']?.toString(),
      previewHint: object['previewHint']?.toString(),
      cooldownSeconds: object['cooldownSeconds'] is num
          ? (object['cooldownSeconds'] as num).toInt()
          : null,
    );
  }

  @override
  Future<void> resetPassword({
    required String username,
    required String resetToken,
    required String newPassword,
  }) async {
    await _client.postObject(
      '/auth/reset-password',
      body: <String, dynamic>{
        'username': username,
        'resetToken': resetToken,
        'newPassword': newPassword,
      },
    );
  }

  @override
  Future<void> logout() async {
    await _client.postObject(
      '/auth/logout',
      body: const <String, dynamic>{},
    );
  }

  @override
  Future<List<TenantSummary>> listTenants() async {
    final items = await _client.getList('/tenants', listKey: 'tenants');
    return items
        .whereType<Map<String, dynamic>>()
        .map(
          (tenant) => TenantSummary(
            id: (tenant['id'] ?? '').toString(),
            code: (tenant['code'] ?? '').toString(),
            name: (tenant['name'] ?? '未命名机构').toString(),
            role: (tenant['role'] ?? 'member').toString(),
            kind: (tenant['kind'] ?? 'organization').toString(),
          ),
        )
        .toList();
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
      name: (tenant['name'] ?? '未命名机构').toString(),
      role: 'member',
      kind: (tenant['kind'] ?? 'organization').toString(),
    );
  }

  @override
  Future<TenantSummary> createTenant({
    required String code,
    required String name,
  }) async {
    final currentSession = currentSessionProvider?.call();
    final object = await _client.postObject(
      '/tenants',
      body: <String, dynamic>{
        'code': code,
        'name': name,
        if ((currentSession?.userId ?? '').isNotEmpty)
          'creatorUserId': currentSession!.userId,
        if ((currentSession?.username ?? '').isNotEmpty)
          'creatorUsername': currentSession!.username,
      },
    );
    final tenant = object['tenant'];
    if (tenant is Map<String, dynamic>) {
      return TenantSummary(
        id: (tenant['id'] ?? '').toString(),
        code: (tenant['code'] ?? code).toString(),
        name: (tenant['name'] ?? name).toString(),
        role: 'owner',
        kind: (tenant['kind'] ?? 'organization').toString(),
      );
    }
    return TenantSummary(
      id: '',
      code: code,
      name: name,
      role: 'owner',
      kind: 'organization',
    );
  }

  @override
  Future<List<TenantMemberSummary>> listTenantMembers({
    required String tenantCode,
  }) async {
    final items = await _client.getList('/tenant-members', listKey: 'members');
    return items
        .whereType<Map<String, dynamic>>()
        .map(
          (member) => TenantMemberSummary(
            id: (member['id'] ?? '').toString(),
            userId: (member['userId'] ?? '').toString(),
            username: (member['username'] ?? 'unknown').toString(),
            role: (member['role'] ?? 'member').toString(),
            status: (member['status'] ?? 'active').toString(),
            createdAtLabel: (member['createdAtLabel'] ?? '最近').toString(),
            updatedAtIso: (member['updatedAt'] ?? '').toString().isEmpty
                ? null
                : (member['updatedAt'] ?? '').toString(),
            invitationExpiresAtIso:
                (member['invitationExpiresAt'] ?? '').toString().isEmpty
                    ? null
                    : (member['invitationExpiresAt'] ?? '').toString(),
          ),
        )
        .toList();
  }

  @override
  Future<TenantMemberSummary> updateTenantMemberRole({
    required String tenantCode,
    required String memberId,
    required String role,
  }) async {
    final object = await _client.patchObject(
      '/tenant-members/$memberId/role',
      body: <String, dynamic>{'role': role},
    );
    final member = object['membership'];
    if (member is Map<String, dynamic>) {
      return TenantMemberSummary(
        id: (member['id'] ?? '').toString(),
        userId: (member['userId'] ?? '').toString(),
        username: (member['username'] ?? 'unknown').toString(),
        role: (member['role'] ?? role).toString(),
        status: (member['status'] ?? 'active').toString(),
        createdAtLabel: '刚刚更新',
        updatedAtIso: (member['updatedAt'] ?? '').toString().isEmpty
            ? null
            : (member['updatedAt'] ?? '').toString(),
        invitationExpiresAtIso:
            (member['invitationExpiresAt'] ?? '').toString().isEmpty
                ? null
                : (member['invitationExpiresAt'] ?? '').toString(),
      );
    }
    return TenantMemberSummary(
      id: memberId,
      userId: '',
      username: 'unknown',
      role: role,
      status: 'active',
      createdAtLabel: '刚刚更新',
    );
  }

  @override
  Future<TenantMemberSummary> addTenantMember({
    required String tenantCode,
    required String username,
    required String role,
    String status = 'active',
  }) async {
    final object = await _client.postObject(
      '/tenant-members',
      body: <String, dynamic>{
        'tenantCode': tenantCode,
        'username': username,
        'role': role,
        'status': status,
      },
    );
    final member = object['membership'];
    if (member is Map<String, dynamic>) {
      return TenantMemberSummary(
        id: (member['id'] ?? '').toString(),
        userId: (member['userId'] ?? '').toString(),
        username: (member['username'] ?? username).toString(),
        role: (member['role'] ?? role).toString(),
        status: (member['status'] ?? status).toString(),
        createdAtLabel: '刚刚加入',
        updatedAtIso: (member['updatedAt'] ?? '').toString().isEmpty
            ? null
            : (member['updatedAt'] ?? '').toString(),
        invitationExpiresAtIso:
            (member['invitationExpiresAt'] ?? '').toString().isEmpty
                ? null
                : (member['invitationExpiresAt'] ?? '').toString(),
      );
    }
    return TenantMemberSummary(
      id: '',
      userId: '',
      username: username,
      role: role,
      status: status,
      createdAtLabel: '刚刚加入',
    );
  }

  @override
  Future<TenantMemberSummary> joinCurrentTenant({
    required String tenantCode,
    required String role,
    String status = 'active',
  }) async {
    final object = await _client.postObject(
      '/tenant-members',
      body: <String, dynamic>{
        'tenantCode': tenantCode,
        'role': role,
        'status': status,
      },
    );
    final member = object['membership'];
    if (member is Map<String, dynamic>) {
      return TenantMemberSummary(
        id: (member['id'] ?? '').toString(),
        userId: (member['userId'] ?? '').toString(),
        username: (member['username'] ?? 'current-user').toString(),
        role: (member['role'] ?? role).toString(),
        status: (member['status'] ?? status).toString(),
        createdAtLabel: '刚刚加入',
        updatedAtIso: (member['updatedAt'] ?? '').toString().isEmpty
            ? null
            : (member['updatedAt'] ?? '').toString(),
        invitationExpiresAtIso:
            (member['invitationExpiresAt'] ?? '').toString().isEmpty
                ? null
                : (member['invitationExpiresAt'] ?? '').toString(),
      );
    }
    return TenantMemberSummary(
      id: '',
      userId: '',
      username: 'current-user',
      role: role,
      status: status,
      createdAtLabel: '刚刚加入',
    );
  }

  @override
  Future<TenantMemberSummary> updateTenantMemberStatus({
    required String tenantCode,
    required String memberId,
    required String status,
  }) async {
    final object = await _client.patchObject(
      '/tenant-members/$memberId/status',
      body: <String, dynamic>{'status': status},
    );
    final member = object['membership'];
    if (member is Map<String, dynamic>) {
      return TenantMemberSummary(
        id: (member['id'] ?? memberId).toString(),
        userId: (member['userId'] ?? '').toString(),
        username: (member['username'] ?? 'unknown').toString(),
        role: (member['role'] ?? 'member').toString(),
        status: (member['status'] ?? status).toString(),
        createdAtLabel: '刚刚更新',
        updatedAtIso: (member['updatedAt'] ?? '').toString().isEmpty
            ? null
            : (member['updatedAt'] ?? '').toString(),
        invitationExpiresAtIso:
            (member['invitationExpiresAt'] ?? '').toString().isEmpty
                ? null
                : (member['invitationExpiresAt'] ?? '').toString(),
      );
    }
    return TenantMemberSummary(
      id: memberId,
      userId: '',
      username: 'unknown',
      role: 'member',
      status: status,
      createdAtLabel: '刚刚更新',
    );
  }

  @override
  Future<TenantMemberSummary> resendTenantMemberInvite({
    required String tenantCode,
    required String memberId,
  }) async {
    final object = await _client.postObject(
      '/tenant-members/$memberId/resend-invite',
      headers: <String, String>{'x-tenant-code': tenantCode},
    );
    final member = object['membership'];
    if (member is Map<String, dynamic>) {
      return TenantMemberSummary(
        id: (member['id'] ?? memberId).toString(),
        userId: (member['userId'] ?? '').toString(),
        username: (member['username'] ?? 'unknown').toString(),
        role: (member['role'] ?? 'member').toString(),
        status: (member['status'] ?? 'invited').toString(),
        createdAtLabel: '刚刚邀请',
        updatedAtIso: (member['updatedAt'] ?? '').toString().isEmpty
            ? null
            : (member['updatedAt'] ?? '').toString(),
        invitationExpiresAtIso:
            (member['invitationExpiresAt'] ?? '').toString().isEmpty
                ? null
                : (member['invitationExpiresAt'] ?? '').toString(),
      );
    }
    return TenantMemberSummary(
      id: memberId,
      userId: '',
      username: 'unknown',
      role: 'member',
      status: 'invited',
      createdAtLabel: '刚刚邀请',
    );
  }

  @override
  Future<void> removeTenantMember({
    required String tenantCode,
    required String memberId,
  }) async {
    await _client.deleteObject('/tenant-members/$memberId');
  }

  @override
  Future<List<TenantMemberAuditEvent>> listTenantMemberAuditEvents({
    required String tenantCode,
    required String userId,
    int limit = 5,
  }) async {
    final items = await _client.getList(
      '/audit-logs',
      query: <String, String>{
        'userId': userId,
        'limit': '$limit',
      },
      headers: <String, String>{'x-tenant-code': tenantCode},
      listKey: 'logs',
    );
    return items.whereType<Map<String, dynamic>>().map((log) {
      final action = (log['action'] ?? 'unknown').toString();
      final targetType = (log['targetType'] ?? 'unknown').toString();
      final targetId = (log['targetId'] ?? '').toString();
      final at = (log['at'] ?? '').toString();
      return TenantMemberAuditEvent(
        id: (log['id'] ?? '').toString(),
        atLabel: at.isEmpty ? '-' : at,
        action: action,
        targetType: targetType,
        detail: targetId.isEmpty
            ? '$action · $targetType'
            : '$action · $targetType · $targetId',
      );
    }).toList();
  }
}
