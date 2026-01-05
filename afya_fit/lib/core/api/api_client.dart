import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:afya_fit/core/constants/api_constants.dart';

class ApiClient {
  final http.Client _client;
  final String baseUrl;

  ApiClient({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? ApiConstants.apiBaseUrl;

  // Get stored auth token
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Store auth token
  Future<void> _setAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // Clear auth token
  Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Build headers with authentication
  Future<Map<String, String>> _buildHeaders({
    Map<String, String>? additionalHeaders,
  }) async {
    final token = await _getAuthToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (additionalHeaders != null) ...additionalHeaders,
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // Handle response
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {};
      }
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(response),
      );
    }
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final body = json.decode(response.body) as Map<String, dynamic>;
      return body['error'] as String? ?? 
             body['message'] as String? ?? 
             'An error occurred';
    } catch (_) {
      return 'An error occurred';
    }
  }

  // GET request
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    var uri = Uri.parse('$baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    final response = await _client.get(
      uri,
      headers: await _buildHeaders(),
    );

    return _handleResponse(response);
  }

  // POST request
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _buildHeaders(),
      body: body != null ? json.encode(body) : null,
    );

    return _handleResponse(response);
  }

  // PUT request
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _client.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _buildHeaders(),
      body: body != null ? json.encode(body) : null,
    );

    return _handleResponse(response);
  }

  // DELETE request
  Future<void> delete(String endpoint) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _buildHeaders(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(response),
      );
    }
  }

  // Get current user
  Future<Map<String, dynamic>> getCurrentUser() async {
    return await get(ApiConstants.me);
  }

  // Login and store token
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _client.post(
      Uri.parse('$baseUrl${ApiConstants.login}'),
      headers: await _buildHeaders(),
      body: json.encode({
        'user': {
          'email': email,
          'password': password,
        },
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Handle empty response
      if (response.body.isEmpty) {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Empty response body from server',
        );
      }
      
      // Extract token from response
      Map<String, dynamic> body;
      try {
        body = json.decode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Invalid JSON response: ${response.body}. Error: $e',
        );
      }
      
      // The API returns { "data": { ...user... }, "token": "..." }
      String? token;
      
      // Check for token at top level first
      if (body.containsKey('token')) {
        token = body['token'] as String?;
      }
      
      // If token is null or empty, throw an error with response details
      if (token == null || token.isEmpty) {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'No token received from server. Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}',
        );
      }
      
      // Store the token
      await _setAuthToken(token);
      
      return body;
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(response),
      );
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException: $statusCode - $message';
}
