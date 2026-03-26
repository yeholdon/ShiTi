import 'dart:convert';

import 'package:http/http.dart' as http;

class HttpJsonException implements Exception {
  const HttpJsonException({
    required this.statusCode,
    required this.message,
    this.body,
  });

  final int statusCode;
  final String message;
  final String? body;

  @override
  String toString() => 'HttpJsonException($statusCode): $message';
}

class HttpJsonClient {
  HttpJsonClient({
    required this.baseUrl,
    this.defaultHeadersBuilder,
    this.onUnauthorized,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final Map<String, String> Function()? defaultHeadersBuilder;
  final void Function()? onUnauthorized;
  final http.Client _client;

  Uri _resolve(String path, [Map<String, String>? query]) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalizedBase$path').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> getObject(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    String? objectKey,
  }) async {
    final response = await _client.get(
      _resolve(path, query),
      headers: _mergeHeaders(headers),
    );
    return _decodeObject(
      response,
      objectKey: objectKey,
      requestHeaders: _mergeHeaders(headers),
    );
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    String? listKey,
  }) async {
    final response = await _client.get(
      _resolve(path, query),
      headers: _mergeHeaders(headers),
    );
    final decoded =
        _decodeJson(response, requestHeaders: _mergeHeaders(headers));
    if (decoded is List<dynamic>) {
      return decoded;
    }
    if (decoded is Map<String, dynamic>) {
      if (listKey != null) {
        final keyed = decoded[listKey];
        if (keyed is List<dynamic>) {
          return keyed;
        }
      }
      final items = decoded['items'];
      if (items is List<dynamic>) {
        return items;
      }
    }
    return const <dynamic>[];
  }

  Future<Map<String, dynamic>> postObject(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final response = await _client.post(
      _resolve(path),
      headers: <String, String>{
        'Content-Type': 'application/json',
        ..._mergeHeaders(headers),
      },
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    return _decodeObject(
      response,
      requestHeaders: <String, String>{
        'Content-Type': 'application/json',
        ..._mergeHeaders(headers),
      },
    );
  }

  Future<Map<String, dynamic>> patchObject(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final response = await _client.patch(
      _resolve(path),
      headers: <String, String>{
        'Content-Type': 'application/json',
        ..._mergeHeaders(headers),
      },
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    return _decodeObject(
      response,
      requestHeaders: <String, String>{
        'Content-Type': 'application/json',
        ..._mergeHeaders(headers),
      },
    );
  }

  Future<Map<String, dynamic>> putObject(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final response = await _client.put(
      _resolve(path),
      headers: <String, String>{
        'Content-Type': 'application/json',
        ..._mergeHeaders(headers),
      },
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    return _decodeObject(
      response,
      requestHeaders: <String, String>{
        'Content-Type': 'application/json',
        ..._mergeHeaders(headers),
      },
    );
  }

  Future<Map<String, dynamic>> deleteObject(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    final response = await _client.delete(
      _resolve(path, query),
      headers: _mergeHeaders(headers),
    );
    return _decodeObject(
      response,
      requestHeaders: _mergeHeaders(headers),
    );
  }

  Map<String, String> _mergeHeaders(Map<String, String>? headers) {
    return <String, String>{
      ...?defaultHeadersBuilder?.call(),
      ...?headers,
    };
  }

  dynamic _decodeJson(
    http.Response response, {
    Map<String, String>? requestHeaders,
  }) {
    _ensureSuccess(response, requestHeaders: requestHeaders);
    if (response.body.isEmpty) {
      return const <String, dynamic>{};
    }
    return jsonDecode(response.body);
  }

  Map<String, dynamic> _decodeObject(
    http.Response response, {
    String? objectKey,
    Map<String, String>? requestHeaders,
  }) {
    final decoded = _decodeJson(response, requestHeaders: requestHeaders);
    if (decoded is Map<String, dynamic>) {
      if (objectKey != null) {
        final keyed = decoded[objectKey];
        if (keyed is Map<String, dynamic>) {
          return keyed;
        }
      }
      return decoded;
    }
    return const <String, dynamic>{};
  }

  void _ensureSuccess(
    http.Response response, {
    Map<String, String>? requestHeaders,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final sentAuthorization = (requestHeaders ?? const <String, String>{})
        .keys
        .any((key) => key.toLowerCase() == 'authorization');

    if (response.statusCode == 401 && sentAuthorization) {
      onUnauthorized?.call();
    }

    String message = '请求失败';
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final error = decoded['error'];
          if (error is Map<String, dynamic>) {
            final errorMessage = error['message'];
            if (errorMessage is String && errorMessage.trim().isNotEmpty) {
              message = errorMessage.trim();
            }
          }
          final topLevelMessage = decoded['message'];
          if (message == '请求失败' &&
              topLevelMessage is String &&
              topLevelMessage.trim().isNotEmpty) {
            message = topLevelMessage.trim();
          }
        }
      } catch (_) {
        // Keep default message when response body is not JSON.
      }
    }

    throw HttpJsonException(
      statusCode: response.statusCode,
      message: message,
      body: response.body.isEmpty ? null : response.body,
    );
  }
}
