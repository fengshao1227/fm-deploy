import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/environment.dart';
import 'api_service.dart';

/// 环境服务
class EnvironmentService {
  final ApiService _api = ApiService();

  /// 获取环境列表（分页）
  Future<ApiResponse<PaginatedData<Environment>>> getEnvironments({
    int page = 1,
    int pageSize = 10,
    String? keyword,
  }) async {
    final params = {
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (keyword != null && keyword.isNotEmpty) {
      params['keyword'] = keyword;
    }

    final response = await _api.get(
      ApiConfig.environments,
      queryParameters: params,
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final listData = data['data'] as Map<String, dynamic>;
        final list = (listData['list'] as List)
            .map((e) => Environment.fromJson(e as Map<String, dynamic>))
            .toList();
        final pagination = Pagination.fromJson(
            listData['pagination'] as Map<String, dynamic>);

        return ApiResponse.success(PaginatedData(
          list: list,
          pagination: pagination,
        ));
      }
    }

    return ApiResponse.error(response.data?['error'] ?? '获取环境列表失败');
  }

  /// 获取所有环境（下拉选择用）
  Future<ApiResponse<List<EnvironmentSimple>>> getAllEnvironments() async {
    final response = await _api.get(ApiConfig.environmentsAll);

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final list = (data['data'] as List)
            .map((e) => EnvironmentSimple.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(list);
      }
    }

    return ApiResponse.error(response.data?['error'] ?? '获取环境列表失败');
  }

  /// 获取环境详情
  Future<ApiResponse<Environment>> getEnvironment(int id) async {
    final response = await _api.get('${ApiConfig.environments}/$id');

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return ApiResponse.success(
            Environment.fromJson(data['data'] as Map<String, dynamic>));
      }
    }

    return ApiResponse.error(response.data?['error'] ?? '获取环境详情失败');
  }

  /// 创建环境
  Future<ApiResponse<Environment>> createEnvironment({
    required String name,
    required String sshHost,
    required int sshPort,
    required String sshUser,
    String? sshKeyPath,
    String? description,
  }) async {
    final response = await _api.post(
      ApiConfig.environments,
      data: {
        'name': name,
        'sshHost': sshHost,
        'sshPort': sshPort,
        'sshUser': sshUser,
        if (sshKeyPath != null) 'sshKeyPath': sshKeyPath,
        if (description != null) 'description': description,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return ApiResponse.success(
            Environment.fromJson(data['data'] as Map<String, dynamic>));
      }
    }

    return ApiResponse.error(response.data?['error'] ?? '创建环境失败');
  }

  /// 更新环境
  Future<ApiResponse<Environment>> updateEnvironment(
    int id, {
    String? name,
    String? sshHost,
    int? sshPort,
    String? sshUser,
    String? sshKeyPath,
    String? description,
  }) async {
    final updateData = <String, dynamic>{};
    if (name != null) updateData['name'] = name;
    if (sshHost != null) updateData['sshHost'] = sshHost;
    if (sshPort != null) updateData['sshPort'] = sshPort;
    if (sshUser != null) updateData['sshUser'] = sshUser;
    if (sshKeyPath != null) updateData['sshKeyPath'] = sshKeyPath;
    if (description != null) updateData['description'] = description;

    final response = await _api.put(
      '${ApiConfig.environments}/$id',
      data: updateData,
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return ApiResponse.success(
            Environment.fromJson(data['data'] as Map<String, dynamic>));
      }
    }

    return ApiResponse.error(response.data?['error'] ?? '更新环境失败');
  }

  /// 删除环境
  Future<ApiResponse<void>> deleteEnvironment(int id) async {
    final response = await _api.delete('${ApiConfig.environments}/$id');

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return ApiResponse.success(null);
      }
    }

    return ApiResponse.error(response.data?['error'] ?? '删除环境失败');
  }

  /// 测试SSH连接
  Future<ApiResponse<SshTestResult>> testSshConnection(int id) async {
    final response = await _api.post('${ApiConfig.environments}/$id/test');

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return ApiResponse.success(
            SshTestResult.fromJson(data['data'] as Map<String, dynamic>));
      }
    }

    return ApiResponse.error(response.data?['error'] ?? '测试连接失败');
  }

  /// 获取项目的环境配置列表
  Future<ApiResponse<List<ProjectEnvironment>>> getProjectEnvironments(
      int projectId) async {
    try {
      final response =
          await _api.get('${ApiConfig.projects}/$projectId/environments');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true) {
          final list = (data['data'] as List)
              .map((e) => ProjectEnvironment.fromJson(e as Map<String, dynamic>))
              .toList();
          return ApiResponse.success(list);
        }
      }

      return ApiResponse.error(response.data?['error'] ?? '获取项目环境配置失败');
    } catch (e) {
      return ApiResponse.error('数据解析错误: $e');
    }
  }

  /// 获取项目环境配置详情
  Future<ApiResponse<ProjectEnvironment>> getProjectEnvironment(int id) async {
    final response = await _api.get('${ApiConfig.projectEnvironments}/$id');

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return ApiResponse.success(
            ProjectEnvironment.fromJson(data['data'] as Map<String, dynamic>));
      }
    }

    return ApiResponse.error(response.data?['error'] ?? '获取配置详情失败');
  }

  /// 创建项目环境配置
  Future<ApiResponse<ProjectEnvironment>> createProjectEnvironment(
    int projectId, {
    required int environmentId,
    required String deployPath,
    required String branch,
    String deployMode = 'push',
    String buildOutputPath = 'dist',
    String? buildCommand,
    String? preDeployCommand,
    String? postDeployCommand,
  }) async {
    final response = await _api.post(
      '${ApiConfig.projects}/$projectId/environments',
      data: {
        'environmentId': environmentId,
        'deployPath': deployPath,
        'branch': branch,
        'deployMode': deployMode,
        'buildOutputPath': buildOutputPath,
        if (buildCommand != null) 'buildCommand': buildCommand,
        if (preDeployCommand != null) 'preDeployCommand': preDeployCommand,
        if (postDeployCommand != null) 'postDeployCommand': postDeployCommand,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return ApiResponse.success(
            ProjectEnvironment.fromJson(data['data'] as Map<String, dynamic>));
      }
    }

    return ApiResponse.error(response.data?['error'] ?? '创建配置失败');
  }

  /// 更新项目环境配置
  Future<ApiResponse<ProjectEnvironment>> updateProjectEnvironment(
    int id, {
    String? deployPath,
    String? branch,
    String? deployMode,
    String? buildOutputPath,
    String? buildCommand,
    String? preDeployCommand,
    String? postDeployCommand,
  }) async {
    final updateData = <String, dynamic>{};
    if (deployPath != null) updateData['deployPath'] = deployPath;
    if (branch != null) updateData['branch'] = branch;
    if (deployMode != null) updateData['deployMode'] = deployMode;
    if (buildOutputPath != null) updateData['buildOutputPath'] = buildOutputPath;
    if (buildCommand != null) updateData['buildCommand'] = buildCommand;
    if (preDeployCommand != null) {
      updateData['preDeployCommand'] = preDeployCommand;
    }
    if (postDeployCommand != null) {
      updateData['postDeployCommand'] = postDeployCommand;
    }

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

    return ApiResponse.error(response.data?['error'] ?? '更新配置失败');
  }

  /// 删除项目环境配置
  Future<ApiResponse<void>> deleteProjectEnvironment(int id) async {
    final response =
        await _api.delete('${ApiConfig.projectEnvironments}/$id');

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return ApiResponse.success(null);
      }
    }

    return ApiResponse.error(response.data?['error'] ?? '删除配置失败');
  }

  /// 启用/禁用项目环境配置
  Future<ApiResponse<ProjectEnvironment>> toggleProjectEnvironment(
      int id) async {
    final response =
        await _api.post('${ApiConfig.projectEnvironments}/$id/toggle');

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return ApiResponse.success(
            ProjectEnvironment.fromJson(data['data'] as Map<String, dynamic>));
      }
    }

    return ApiResponse.error(response.data?['error'] ?? '操作失败');
  }
}
