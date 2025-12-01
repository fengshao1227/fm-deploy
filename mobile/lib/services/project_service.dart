import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/project.dart';
import 'api_service.dart';
import '../models/environment.dart'; // New import for ProjectSimple

/// 项目服务
class ProjectService {
  final ApiService _api = ApiService();

  /// 获取项目列表（分页）
  Future<ApiResponse<PaginatedData<Project>>> getProjects({
    int page = 1,
    int pageSize = 10,
    String? type,
    String? keyword,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };
      if (type != null && type.isNotEmpty) {
        queryParams['type'] = type;
      }
      if (keyword != null && keyword.isNotEmpty) {
        queryParams['keyword'] = keyword;
      }

      final response = await _api.get(
        ApiConfig.projects,
        queryParameters: queryParams,
      );

      return ApiResponse<PaginatedData<Project>>(
        success: response.data['success'] ?? false,
        data: response.data['success'] == true
            ? PaginatedData<Project>.fromJson(
                response.data['data'],
                (json) => Project.fromJson(json),
              )
            : null,
        error: response.data['error'],
      );
    } catch (e) {
      return ApiResponse<PaginatedData<Project>>(
        success: false,
        error: ApiService.getErrorMessage(e),
      );
    }
  }

  /// 获取所有项目（简单列表）
  Future<ApiResponse<List<ProjectSimple>>> getAllProjects() async {
    try {
      final response = await _api.get(ApiConfig.projectsAll);

      return ApiResponse<List<ProjectSimple>>(
        success: response.data['success'] ?? false,
        data: response.data['success'] == true
            ? (response.data['data'] as List)
                .map((e) => ProjectSimple.fromJson(e))
                .toList()
            : null,
        error: response.data['error'],
      );
    } catch (e) {
      return ApiResponse<List<ProjectSimple>>(
        success: false,
        error: ApiService.getErrorMessage(e),
      );
    }
  }

  /// 获取项目详情
  Future<ApiResponse<Project>> getProject(int id) async {
    try {
      final response = await _api.get('${ApiConfig.projects}/$id');

      return ApiResponse<Project>(
        success: response.data['success'] ?? false,
        data: response.data['success'] == true
            ? Project.fromJson(response.data['data'])
            : null,
        error: response.data['error'],
      );
    } catch (e) {
      return ApiResponse<Project>(
        success: false,
        error: ApiService.getErrorMessage(e),
      );
    }
  }

  /// 创建项目
  Future<ApiResponse<Project>> createProject({
    required String name,
    required String projectKey,
    required String type,
    String? gitRepo,
    String? description,
  }) async {
    try {
      final response = await _api.post(
        ApiConfig.projects,
        data: {
          'name': name,
          'projectKey': projectKey,
          'type': type,
          if (gitRepo != null) 'gitRepo': gitRepo,
          if (description != null) 'description': description,
        },
      );

      return ApiResponse<Project>(
        success: response.data['success'] ?? false,
        data: response.data['success'] == true && response.data['data'] != null
            ? Project.fromJson(response.data['data'])
            : null,
        message: response.data['message'],
        error: response.data['error'],
      );
    } catch (e) {
      return ApiResponse<Project>(
        success: false,
        error: ApiService.getErrorMessage(e),
      );
    }
  }

  /// 更新项目
  Future<ApiResponse<Project>> updateProject(
    int id, {
    String? name,
    String? gitRepo,
    String? description,
  }) async {
    try {
      final response = await _api.put(
        '${ApiConfig.projects}/$id',
        data: {
          if (name != null) 'name': name,
          if (gitRepo != null) 'gitRepo': gitRepo,
          if (description != null) 'description': description,
        },
      );

      return ApiResponse<Project>(
        success: response.data['success'] ?? false,
        data: response.data['success'] == true && response.data['data'] != null
            ? Project.fromJson(response.data['data'])
            : null,
        message: response.data['message'],
        error: response.data['error'],
      );
    } catch (e) {
      return ApiResponse<Project>(
        success: false,
        error: ApiService.getErrorMessage(e),
      );
    }
  }

  /// 删除项目
  Future<ApiResponse<void>> deleteProject(int id) async {
    try {
      final response = await _api.delete('${ApiConfig.projects}/$id');

      return ApiResponse<void>(
        success: response.data['success'] ?? false,
        message: response.data['message'],
        error: response.data['error'],
      );
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        error: ApiService.getErrorMessage(e),
      );
    }
  }
}
