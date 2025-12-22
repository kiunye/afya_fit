import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:afya_fit/core/api/api_client.dart';

part 'api_provider.g.dart';

@riverpod
ApiClient apiClient(Ref ref) {
  return ApiClient();
}
