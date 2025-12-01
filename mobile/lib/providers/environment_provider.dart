import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/api_response.dart'; // Import ApiResponse
import '../models/environment.dart';
import '../services/environment_service.dart';

/// 环境列表状态
class EnvironmentListState {
  final List<Environment> environments;
  final bool isLoading;
  final String? error;
  final int currentPage;
  final int totalPages;
  final bool hasMore;
  final String? keyword;

  EnvironmentListState({
    this.environments = const [],
    this.isLoading = false,
    this.error,
    this.currentPage = 1,
    this.totalPages = 1,
    this.hasMore = true,
    this.keyword,
  });

  EnvironmentListState copyWith({
    List<Environment>? environments,
    bool? isLoading,
    String? error,
    int? currentPage,
    int? totalPages,
    bool? hasMore,
    String? keyword,
  }) {
    return EnvironmentListState(
      environments: environments ?? this.environments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      hasMore: hasMore ?? this.hasMore,
      keyword: keyword ?? this.keyword,
    );
  }
}

/// 环境列表状态管理
class EnvironmentListNotifier extends StateNotifier<EnvironmentListState> {
  final EnvironmentService _service = EnvironmentService();

  EnvironmentListNotifier() : super(EnvironmentListState());

  /// 加载环境列表
  Future<void> loadEnvironments() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    final response = await _service.getEnvironments(
      page: 1,
      keyword: state.keyword,
    );

    if (response.success && response.data != null) {
      final data = response.data!;
      state = state.copyWith(
        environments: data.list,
        isLoading: false,
        currentPage: data.pagination.page,
        totalPages: data.pagination.totalPages,
        hasMore: data.pagination.page < data.pagination.totalPages,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: response.error ?? '加载失败',
      );
    }
  }

  /// 加载更多
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    final response = await _service.getEnvironments(
      page: state.currentPage + 1,
      keyword: state.keyword,
    );

    if (response.success && response.data != null) {
      final data = response.data!;
      state = state.copyWith(
        environments: [...state.environments, ...data.list],
        isLoading: false,
        currentPage: data.pagination.page,
        totalPages: data.pagination.totalPages,
        hasMore: data.pagination.page < data.pagination.totalPages,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: response.error,
      );
    }
  }

  /// 刷新
  Future<void> refresh() async {
    state = EnvironmentListState(keyword: state.keyword);
    await loadEnvironments();
  }

  /// 搜索
  Future<void> search(String? keyword) async {
    state = EnvironmentListState(keyword: keyword);
    await loadEnvironments();
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
    final response = await _service.createEnvironment(
      name: name,
      sshHost: sshHost,
      sshPort: sshPort,
      sshUser: sshUser,
      sshKeyPath: sshKeyPath,
      description: description,
    );

    if (response.success) {
      refresh();
    }
    return response;
  }
}

/// 环境详情状态
class EnvironmentDetailState {
  final Environment? environment;
  final bool isLoading;
  final String? error;

  EnvironmentDetailState({
    this.environment,
    this.isLoading = false,
    this.error,
  });

  EnvironmentDetailState copyWith({
    Environment? environment,
    bool? isLoading,
    String? error,
  }) {
    return EnvironmentDetailState(
      environment: environment ?? this.environment,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 环境详情状态管理
class EnvironmentDetailNotifier extends StateNotifier<EnvironmentDetailState> {
  final EnvironmentService _service = EnvironmentService();

  EnvironmentDetailNotifier() : super(EnvironmentDetailState());

  /// 加载环境详情
  Future<void> loadEnvironment(int id) async {
    state = EnvironmentDetailState(isLoading: true);

    final response = await _service.getEnvironment(id);

    if (response.success && response.data != null) {
      state = EnvironmentDetailState(environment: response.data);
    } else {
      state = EnvironmentDetailState(error: response.error ?? '加载失败');
    }
  }

  /// 测试 SSH 连接
  Future<SshTestResult?> testConnection(int id) async {
    final response = await _service.testSshConnection(id);
    if (response.success) {
      return response.data;
    }
    return null;
  }

  /// 删除环境
  Future<bool> deleteEnvironment(int id) async {
    final response = await _service.deleteEnvironment(id);
    return response.success;
  }
}

/// 所有环境列表（下拉选择用）
class AllEnvironmentsNotifier extends StateNotifier<List<EnvironmentSimple>> {
  final EnvironmentService _service = EnvironmentService();

  AllEnvironmentsNotifier() : super([]);

  Future<void> loadAll() async {
    final response = await _service.getAllEnvironments();
    if (response.success && response.data != null) {
      state = response.data!;
    }
  }
}

/// 项目环境配置列表
class ProjectEnvironmentsState {
  final List<ProjectEnvironment> configs;
  final bool isLoading;
  final String? error;

  ProjectEnvironmentsState({
    this.configs = const [],
    this.isLoading = false,
    this.error,
  });

  ProjectEnvironmentsState copyWith({
    List<ProjectEnvironment>? configs,
    bool? isLoading,
    String? error,
  }) {
    return ProjectEnvironmentsState(
      configs: configs ?? this.configs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 项目环境配置列表管理
class ProjectEnvironmentsNotifier
    extends StateNotifier<ProjectEnvironmentsState> {
  final EnvironmentService _service = EnvironmentService();

  ProjectEnvironmentsNotifier() : super(ProjectEnvironmentsState());

  /// 加载项目的环境配置
  Future<void> loadConfigs(int projectId) async {
    state = ProjectEnvironmentsState(isLoading: true);

    final response = await _service.getProjectEnvironments(projectId);

    if (response.success && response.data != null) {
      state = ProjectEnvironmentsState(configs: response.data!);
    } else {
      state = ProjectEnvironmentsState(error: response.error ?? '加载失败');
    }
  }

  /// 启用/禁用配置
  Future<bool> toggleConfig(int id) async {
    final response = await _service.toggleProjectEnvironment(id);
    if (response.success && response.data != null) {
      // 更新列表中的配置状态
      final updatedConfigs = state.configs.map((config) {
        if (config.id == id) {
          return response.data!;
        }
        return config;
      }).toList();
      state = state.copyWith(configs: updatedConfigs);
      return true;
    }
    return false;
  }

  /// 删除配置
  Future<bool> deleteConfig(int id) async {
    final response = await _service.deleteProjectEnvironment(id);
    if (response.success) {
      state = state.copyWith(
        configs: state.configs.where((c) => c.id != id).toList(),
      );
      return true;
    }
    return false;
  }

  /// 创建配置
  Future<ApiResponse<ProjectEnvironment>> createConfig(
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
    final response = await _service.createProjectEnvironment(
      projectId,
      environmentId: environmentId,
      deployPath: deployPath,
      branch: branch,
      deployMode: deployMode,
      buildOutputPath: buildOutputPath,
      buildCommand: buildCommand,
      preDeployCommand: preDeployCommand,
      postDeployCommand: postDeployCommand,
    );

    if (response.success && response.data != null) {
      state = state.copyWith(
        configs: [...state.configs, response.data!],
      );
    }
    return response;
  }
}

// Providers
final environmentListProvider =
    StateNotifierProvider<EnvironmentListNotifier, EnvironmentListState>(
  (ref) => EnvironmentListNotifier(),
);

final environmentDetailProvider =
    StateNotifierProvider<EnvironmentDetailNotifier, EnvironmentDetailState>(
  (ref) => EnvironmentDetailNotifier(),
);

final allEnvironmentsProvider =
    StateNotifierProvider<AllEnvironmentsNotifier, List<EnvironmentSimple>>(
  (ref) => AllEnvironmentsNotifier(),
);

final projectEnvironmentsProvider =
    StateNotifierProvider<ProjectEnvironmentsNotifier, ProjectEnvironmentsState>(
  (ref) => ProjectEnvironmentsNotifier(),
);
