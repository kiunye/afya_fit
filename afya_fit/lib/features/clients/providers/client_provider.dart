import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:afya_fit/core/providers/api_provider.dart';
import 'package:afya_fit/features/clients/data/repositories/client_repository.dart';

part 'client_provider.g.dart';

@riverpod
ClientRepository clientRepository(Ref ref) {
  return ClientRepository(ref.read(apiClientProvider));
}

@riverpod
Future<List<Map<String, dynamic>>> clients(Ref ref) async {
  final repository = ref.read(clientRepositoryProvider);
  return repository.getClients();
}

@riverpod
Future<Map<String, dynamic>> client(Ref ref, String id) async {
  final repository = ref.read(clientRepositoryProvider);
  return repository.getClient(id);
}

