import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';
import '../models/tenant_summary.dart';

class SessionPersistence {
  SessionPersistence._(this._preferences);

  static const _sessionKey = 'auth_session';
  static const _tenantKey = 'active_tenant';

  final SharedPreferences _preferences;

  static Future<SessionPersistence> create() async {
    final preferences = await SharedPreferences.getInstance();
    return SessionPersistence._(preferences);
  }

  AuthSession? loadSession() {
    final decoded = _loadJsonMap(_sessionKey);
    return decoded == null ? null : AuthSession.fromJson(decoded);
  }

  TenantSummary? loadActiveTenant() {
    final decoded = _loadJsonMap(_tenantKey);
    return decoded == null ? null : TenantSummary.fromJson(decoded);
  }

  Future<void> saveSession(AuthSession? session) async {
    if (session == null) {
      await _preferences.remove(_sessionKey);
      return;
    }
    await _preferences.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<void> saveActiveTenant(TenantSummary? tenant) async {
    if (tenant == null) {
      await _preferences.remove(_tenantKey);
      return;
    }
    await _preferences.setString(_tenantKey, jsonEncode(tenant.toJson()));
  }

  Future<void> clear() async {
    await _preferences.remove(_sessionKey);
    await _preferences.remove(_tenantKey);
  }

  Map<String, dynamic>? _loadJsonMap(String key) {
    try {
      final rawValue = _preferences.get(key);
      if (rawValue == null) {
        return null;
      }
      if (rawValue is Map) {
        return rawValue.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
      if (rawValue is String) {
        if (rawValue.isEmpty) {
          return null;
        }
        final decoded = jsonDecode(rawValue);
        if (decoded is Map) {
          return decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
      }
    } catch (_) {
      // Ignore invalid persisted state and treat it as missing.
    }
    return null;
  }
}
