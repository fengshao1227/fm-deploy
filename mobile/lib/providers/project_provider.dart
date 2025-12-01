import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/api_response.dart';
import '../models/project.dart';
import '../services/project_service.dart';

/// 项目列表状态
class ProjectListState {
  final bool isLoading;
  final bool isLoadingMore;
  final List<Project> projects;
  final Pagination? pagination;
  final String? error;
  final String? typeFilter;
  final String? keyword;

  ProjectListState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.projects = const [],
    this.pagination,
    this.error,
    this.typeFilter,
    this.keyword,
  });

  ProjectListState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<Project>? projects,
    Pagination? pagination,
    String? error,
    String? typeFilter,
    String? keyword,
  }) {
    return ProjectListState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      projects: projects ?? this.projects,
      pagination: pagination ?? this.pagination,
      error: error,
      typeFilter: typeFilter ?? this.typeFilter,
      keyword: keyword ?? this.keyword,
    );
  }

  bool get hasMore => pagination?.hasMore ?? false;
  int get currentPage => pagination?.page ?? 0;
}

/// 项目列表状态管理
class ProjectListNotifier extends StateNotifier<ProjectListState> {
  final ProjectService _projectService = ProjectService();

  ProjectListNotifier() : super(ProjectListState());

  /// 加载项目列表（刷新）
  Future<void> loadProjects({
    String? type,
    String? keyword,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      typeFilter: type,
      keyword: keyword,
    );

    final response = await _projectService.getProjects(
      page: 1,
      type: type,
      keyword: keyword,
    );

    if (response.success && response.data != null) {
      state = state.copyWith(
        isLoading: false,
        projects: response.data!.list,
        pagination: response.data!.pagination,
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
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    final response = await _projectService.getProjects(
      page: state.currentPage + 1,
      type: state.typeFilter,
      keyword: state.keyword,
    );

    if (response.success && response.data != null) {
      state = state.copyWith(
        isLoadingMore: false,
        projects: [...state.projects, ...response.data!.list],
        pagination: response.data!.pagination,
      );
    } else {
      state = state.copyWith(
        isLoadingMore: false,
        error: response.error,
      );
    }
  }

  /// 刷新
  Future<void> refresh() async {
    await loadProjects(
      type: state.typeFilter,
      keyword: state.keyword,
    );
  }

  /// 设置筛选条件
  void setFilter({String? type, String? keyword}) {
    loadProjects(type: type, keyword: keyword);
  }

  /// 清除筛选
  void clearFilter() {
    loadProjects();
  }

  /// 创建项目
  Future<ApiResponse<Project>> createProject({
    required String name,
    required String projectKey,
    required String type,
    String? gitRepo,
    String? description,
  }) async {
    final response = await _projectService.createProject(
      name: name,
      projectKey: projectKey,
      type: type,
      gitRepo: gitRepo,
      description: description,
    );

    if (response.success) {
      refresh(); // 创建成功后刷新列表
    }
    return response;
  }
}

/// 项目列表 Provider
final projectListProvider =
    StateNotifierProvider<ProjectListNotifier, ProjectListState>((ref) {
  return ProjectListNotifier();
});

/// 项目详情状态
class ProjectDetailState {
  final bool isLoading;
  final Project? project;
  final String? error;

  ProjectDetailState({
    this.isLoading = false,
    this.project,
    this.error,
  });

  ProjectDetailState copyWith({
    bool? isLoading,
    Project? project,
    String? error,
  }) {
    return ProjectDetailState(
      isLoading: isLoading ?? this.isLoading,
      project: project ?? this.project,
      error: error,
    );
  }
}

/// 项目详情状态管理
class ProjectDetailNotifier extends StateNotifier<ProjectDetailState> {
  final ProjectService _projectService = ProjectService();

  ProjectDetailNotifier() : super(ProjectDetailState());

  /// 加载项目详情
  Future<void> loadProject(int id) async {
    state = ProjectDetailState(isLoading: true);

    final response = await _projectService.getProject(id);

    if (response.success && response.data != null) {
      state = ProjectDetailState(project: response.data);
    } else {
      state = ProjectDetailState(error: response.error ?? '加载失败');
    }
  }

  /// 删除项目
  Future<bool> deleteProject(int id) async {
    final response = await _projectService.deleteProject(id);
    return response.success;
  }

  /// 更新项目
  Future<ApiResponse<Project>> updateProject(
    int id, {
    String? name,
    String? gitRepo,
    String? description,
  }) async {
    final response = await _projectService.updateProject(
      id,
      name: name,
      gitRepo: gitRepo,
      description: description,
    );

    if (response.success && response.data != null) {
      // 更新本地状态
      final updatedProject = state.project?.copyWith(
        name: name,
        gitRepo: gitRepo,
        description: description,
      );
      if (updatedProject != null) {
        state = state.copyWith(project: updatedProject);
      }
    }
    return response;
  }

  /// 清除状态
  void clear() {
    state = ProjectDetailState();
  }
}

/// 项目详情 Provider
final projectDetailProvider =
    StateNotifierProvider<ProjectDetailNotifier, ProjectDetailState>((ref) {
  return ProjectDetailNotifier();
});
