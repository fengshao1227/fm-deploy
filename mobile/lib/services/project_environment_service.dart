// mobile/lib/services/project_environment_service.dart

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/environment.dart'; // For ProjectEnvironment model
import 'api_service.dart';

class ProjectEnvironmentService {
  final ApiService _api = ApiService();

  /// 获取单个项目环境配置详情
  Future<ApiResponse<ProjectEnvironment>> getProjectEnvironment(int id) async {
    final response = await _api.get('${ApiConfig.projectEnvironments}/$id');

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return ApiResponse.success(
            ProjectEnvironment.fromJson(data['data'] as Map<String, dynamic>));
      }
    }
    return ApiResponse.error(response.data?['error'] ?? '获取项目环境配置失败');
  }

  /// 更新项目环境配置
  Future<ApiResponse<ProjectEnvironment>> updateProjectEnvironment(
      int id, Map<String, dynamic> updateData) async {
    final response = await _api.put(
      '${ApiConfig.projectEnvironments}/$id',
      data: updateData,
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return ApiResponse.success(
            ProjectEnvironment.fromJson(data['data'] as Map<String, dynamic>));
      }
    }
    return ApiResponse.error(response.data?['error'] ?? '更新项目环境配置失败');
  }
}
