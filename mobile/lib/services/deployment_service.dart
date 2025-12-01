import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/deployment.dart';
import 'api_service.dart';

/// 部署服务
class DeploymentService {
  final ApiService _api = ApiService();

  /// 获取部署记录列表（分页）
  Future<ApiResponse<PaginatedData<Deployment>>> getDeployments({
    int page = 1,
    int pageSize = 10,
    int? projectEnvironmentId,
    String? status,
  }) async {
    final params = {
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (projectEnvironmentId != null) {
      params['projectEnvironmentId'] = projectEnvironmentId.toString();
    }
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }

    final response = await _api.get(
      ApiConfig.deployments,
      queryParameters: params,
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final listData = data['data'] as Map<String, dynamic>;
        final list = (listData['list'] as List)
            .map((e) => Deployment.fromJson(e as Map<String, dynamic>))
            .toList();
        final pagination = Pagination.fromJson(
            listData['pagination'] as Map<String, dynamic>);

        return ApiResponse.success(PaginatedData(
          list: list,
          pagination: pagination,
        ));
      }
    }

    return ApiResponse.error(response.data?['error'] ?? '获取部署记录失败');
  }

  /// 获取项目的部署记录
  Future<ApiResponse<PaginatedData<Deployment>>> getProjectDeployments(
    int projectId, {
    int page = 1,
    int pageSize = 10,
  }) async {
    final params = {
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };

    final response = await _api.get(
      '${ApiConfig.projects}/$projectId/deployments',
      queryParameters: params,
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final listData = data['data'] as Map<String, dynamic>;
        final list = (listData['list'] as List)
            .map((e) => Deployment.fromJson(e as Map<String, dynamic>))
            .toList();
        final pagination = Pagination.fromJson(
            listData['pagination'] as Map<String, dynamic>);

        return ApiResponse.success(PaginatedData(
          list: list,
          pagination: pagination,
        ));
      }
    }

    return ApiResponse.error(response.data?['error'] ?? '获取部署记录失败');
  }

  /// 获取部署详情
  Future<ApiResponse<Deployment>> getDeployment(int id) async {
    final response = await _api.get('${ApiConfig.deployments}/$id');

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return ApiResponse.success(
            Deployment.fromJson(data['data'] as Map<String, dynamic>));
      }
    }

    return ApiResponse.error(response.data?['error'] ?? '获取部署详情失败');
  }

  /// 创建部署任务
  Future<ApiResponse<Deployment>> createDeployment(
      int projectEnvironmentId) async {
    final response = await _api.post(
      ApiConfig.deployments,
      data: {'projectEnvironmentId': projectEnvironmentId},
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return ApiResponse.success(
            Deployment.fromJson(data['data'] as Map<String, dynamic>));
      }
    }

    return ApiResponse.error(response.data?['error'] ?? '创建部署任务失败');
  }

  /// 获取部署日志
  Future<ApiResponse<DeploymentLogsData>> getDeploymentLogs(int id) async {
    final response = await _api.get('${ApiConfig.deployments}/$id/logs');

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final logsData = data['data'] as Map<String, dynamic>;
        final logs = (logsData['logs'] as List)
            .map((e) => DeploymentLog.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(DeploymentLogsData(
          deploymentId: logsData['deploymentId'] as int,
          status: DeploymentStatus.fromString(logsData['status'] as String),
          logs: logs,
        ));
      }
    }

    return ApiResponse.error(response.data?['error'] ?? '获取部署日志失败');
  }

  /// 回滚部署
  Future<ApiResponse<Deployment>> rollbackDeployment(int id) async {
    final response = await _api.post('${ApiConfig.deployments}/$id/rollback');

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return ApiResponse.success(
            Deployment.fromJson(data['data'] as Map<String, dynamic>));
      }
    }

    return ApiResponse.error(response.data?['error'] ?? '回滚失败');
  }

  /// 取消部署
  Future<ApiResponse<void>> cancelDeployment(int id) async {
    final response = await _api.post('${ApiConfig.deployments}/$id/cancel');

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return ApiResponse.success(null);
      }
    }

    return ApiResponse.error(response.data?['error'] ?? '取消部署失败');
  }
}

/// 部署日志数据
class DeploymentLogsData {
  final int deploymentId;
  final DeploymentStatus status;
  final List<DeploymentLog> logs;

  DeploymentLogsData({
    required this.deploymentId,
    required this.status,
    required this.logs,
  });
}
