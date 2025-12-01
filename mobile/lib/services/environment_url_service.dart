import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/environment_url.dart';
import 'api_service.dart';

/// 环境 URL 服务
class EnvironmentUrlService {
  final ApiService _api = ApiService();

  /// 获取所有 URL（下拉选择用）
  Future<ApiResponse<List<EnvironmentUrl>>> getAllUrls() async {
    final response = await _api.get('${ApiConfig.environmentUrls}/all');

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final list = (data['data'] as List)
            .map((e) => EnvironmentUrl.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(list);
      }
    }

    return ApiResponse.error(response.data?['error'] ?? '获取 URL 列表失败');
  }

  /// 查找或创建 URL
  Future<ApiResponse<EnvironmentUrl>> findOrCreate(String url) async {
    final response = await _api.post(
      '${ApiConfig.environmentUrls}/find-or-create',
      data: {'url': url},
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return ApiResponse.success(
            EnvironmentUrl.fromJson(data['data'] as Map<String, dynamic>));
      }
    }

    return ApiResponse.error(response.data?['error'] ?? '操作失败');
  }
}
