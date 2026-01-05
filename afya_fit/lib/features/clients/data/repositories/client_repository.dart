import 'package:afya_fit/core/api/api_client.dart';
import 'package:afya_fit/core/constants/api_constants.dart';

class ClientRepository {
  final ApiClient _apiClient;

  ClientRepository(this._apiClient);

  Future<List<Map<String, dynamic>>> getClients() async {
    final response = await _apiClient.get(ApiConstants.clients());
    return List<Map<String, dynamic>>.from(response['data'] ?? []);
  }

  Future<Map<String, dynamic>> getClient(String id) async {
    final response = await _apiClient.get(ApiConstants.client(id));
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> createClient(
    Map<String, dynamic> clientData,
  ) async {
    final response = await _apiClient.post(
      ApiConstants.clients(),
      body: {'client': clientData},
    );
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> updateClient(
    String id,
    Map<String, dynamic> clientData,
  ) async {
    final response = await _apiClient.put(
      ApiConstants.client(id),
      body: {'client': clientData},
    );
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> deleteClient(String id) async {
    await _apiClient.delete(ApiConstants.client(id));
  }

  Future<Map<String, dynamic>> inviteClient(String id) async {
    final response = await _apiClient.post(ApiConstants.clientInvite(id));
    return response['data'] as Map<String, dynamic>? ?? {};
  }
}

