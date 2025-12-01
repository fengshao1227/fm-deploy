// lib/services/version_service.dart

import '../models/backup_version.dart';
import '../models/api_response.dart'; // Need to import ApiResponse
import 'api_service.dart'; // Import ApiService
import '../config/api_config.dart'; // Import ApiConfig

class VersionService {
  final ApiService _api = ApiService(); // Use ApiService

  /// 获取可回滚版本列表
  Future<ApiResponse<List<BackupVersion>>> getVersions(int projectEnvironmentId) async {
    final response = await _api.get(
      '${ApiConfig.projectEnvironments}/$projectEnvironmentId/versions', // Use ApiConfig
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final versions = data['data']['versions'] as List;
        return ApiResponse.success(versions.map((v) => BackupVersion.fromJson(v)).toList());
      }
    }
    return ApiResponse.error(response.data?['error'] ?? '获取版本列表失败');
  }

  /// 回滚到指定版本
  Future<ApiResponse<Map<String, dynamic>>> rollbackToVersion(int snapshotId) async {
    final response = await _api.post(
      '${ApiConfig.snapshots}/$snapshotId/rollback', // Use ApiConfig
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return ApiResponse.success(data['data']);
      }
    }
    return ApiResponse.error(response.data?['error'] ?? '回滚失败');
  }
}