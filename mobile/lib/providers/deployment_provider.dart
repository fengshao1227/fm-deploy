import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/deployment.dart';
import '../services/deployment_service.dart';
import '../services/websocket_service.dart';

/// 部署记录列表状态
class DeploymentListState {
  final List<Deployment> deployments;
  final bool isLoading;
  final String? error;
  final int currentPage;
  final int totalPages;
  final bool hasMore;
  final String? statusFilter;

  DeploymentListState({
    this.deployments = const [],
    this.isLoading = false,
    this.error,
    this.currentPage = 1,
    this.totalPages = 1,
    this.hasMore = true,
    this.statusFilter,
  });

  DeploymentListState copyWith({
    List<Deployment>? deployments,
    bool? isLoading,
    String? error,
    int? currentPage,
    int? totalPages,
    bool? hasMore,
    String? statusFilter,
  }) {
    return DeploymentListState(
      deployments: deployments ?? this.deployments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      hasMore: hasMore ?? this.hasMore,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}

/// 部署记录列表状态管理
class DeploymentListNotifier extends StateNotifier<DeploymentListState> {
  final DeploymentService _service = DeploymentService();

  DeploymentListNotifier() : super(DeploymentListState());

  /// 加载部署记录
  Future<void> loadDeployments() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    final response = await _service.getDeployments(
      page: 1,
      status: state.statusFilter,
    );

    if (response.success && response.data != null) {
      final data = response.data!;
      state = state.copyWith(
        deployments: data.list,
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

    final response = await _service.getDeployments(
      page: state.currentPage + 1,
      status: state.statusFilter,
    );

    if (response.success && response.data != null) {
      final data = response.data!;
      state = state.copyWith(
        deployments: [...state.deployments, ...data.list],
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
    state = DeploymentListState(statusFilter: state.statusFilter);
    await loadDeployments();
  }

  /// 设置状态筛选
  Future<void> setStatusFilter(String? status) async {
    state = DeploymentListState(statusFilter: status);
    await loadDeployments();
  }
}

/// 部署详情状态
class DeploymentDetailState {
  final Deployment? deployment;
  final List<DeploymentLog> logs;
  final bool isLoading;
  final String? error;

  DeploymentDetailState({
    this.deployment,
    this.logs = const [],
    this.isLoading = false,
    this.error,
  });

  DeploymentDetailState copyWith({
    Deployment? deployment,
    List<DeploymentLog>? logs,
    bool? isLoading,
    String? error,
  }) {
    return DeploymentDetailState(
      deployment: deployment ?? this.deployment,
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 部署详情状态管理
class DeploymentDetailNotifier extends StateNotifier<DeploymentDetailState> {
  final DeploymentService _service = DeploymentService();
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _logSubscription;
  Timer? _pollTimer;

  DeploymentDetailNotifier() : super(DeploymentDetailState());

  /// 加载部署详情
  Future<void> loadDeployment(int id) async {
    state = DeploymentDetailState(isLoading: true);

    final response = await _service.getDeployment(id);

    if (response.success && response.data != null) {
      state = DeploymentDetailState(deployment: response.data);
      // 加载日志
      await loadLogs(id);
      // 如果正在执行，订阅实时日志
      if (response.data!.status.isRunning ||
          response.data!.status.isPending) {
        _subscribeRealtimeLogs(id);
      }
    } else {
      state = DeploymentDetailState(error: response.error ?? '加载失败');
    }
  }

  /// 加载部署日志
  Future<void> loadLogs(int id) async {
    final response = await _service.getDeploymentLogs(id);

    if (response.success && response.data != null) {
      state = state.copyWith(logs: response.data!.logs);
      // 更新部署状态
      if (state.deployment != null) {
        final updatedDeployment = Deployment(
          id: state.deployment!.id,
          status: response.data!.status,
          commitHash: state.deployment!.commitHash,
          commitMessage: state.deployment!.commitMessage,
          startedAt: state.deployment!.startedAt,
          finishedAt: state.deployment!.finishedAt,
          errorMessage: state.deployment!.errorMessage,
          createdAt: state.deployment!.createdAt,
          project: state.deployment!.project,
          environment: state.deployment!.environment,
          user: state.deployment!.user,
          projectEnvironment: state.deployment!.projectEnvironment,
        );
        state = state.copyWith(deployment: updatedDeployment);
      }
    }
  }

  /// 订阅实时日志
  void _subscribeRealtimeLogs(int deploymentId) {
    // 尝试使用 WebSocket
    _wsService.connect();
    _wsService.subscribeDeployment(deploymentId);

    _logSubscription = _wsService.logStream.listen((log) {
      if (log.deploymentId == deploymentId) {
        // 添加新日志
        final newLog = DeploymentLog(
          id: DateTime.now().millisecondsSinceEpoch,
          logType: log.logType,
          message: log.message,
          timestamp: log.timestamp,
        );
        state = state.copyWith(logs: [...state.logs, newLog]);
      }
    });

    // 同时使用轮询作为备份
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollLogs(deploymentId);
    });
  }

  /// 轮询日志
  Future<void> _pollLogs(int deploymentId) async {
    final response = await _service.getDeploymentLogs(deploymentId);
    if (response.success && response.data != null) {
      // 检查状态变化
      if (response.data!.status.isSuccess || response.data!.status.isFailed) {
        // 部署完成，停止轮询
        _stopPolling();
        // 重新加载详情
        loadDeployment(deploymentId);
      }
    }
  }

  /// 停止轮询和订阅
  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _logSubscription?.cancel();
    _logSubscription = null;
    if (state.deployment != null) {
      _wsService.unsubscribeDeployment(state.deployment!.id);
    }
  }

  /// 回滚部署
  Future<bool> rollback(int id) async {
    final response = await _service.rollbackDeployment(id);
    return response.success;
  }

  /// 取消部署
  Future<bool> cancel(int id) async {
    final response = await _service.cancelDeployment(id);
    if (response.success) {
      // 重新加载详情
      await loadDeployment(id);
    }
    return response.success;
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}

/// 创建部署状态
class CreateDeploymentState {
  final bool isCreating;
  final Deployment? deployment;
  final String? error;

  CreateDeploymentState({
    this.isCreating = false,
    this.deployment,
    this.error,
  });
}

/// 创建部署状态管理
class CreateDeploymentNotifier extends StateNotifier<CreateDeploymentState> {
  final DeploymentService _service = DeploymentService();

  CreateDeploymentNotifier() : super(CreateDeploymentState());

  /// 创建部署任务
  Future<Deployment?> createDeployment(int projectEnvironmentId) async {
    state = CreateDeploymentState(isCreating: true);

    final response = await _service.createDeployment(projectEnvironmentId);

    if (response.success && response.data != null) {
      state = CreateDeploymentState(deployment: response.data);
      return response.data;
    } else {
      state = CreateDeploymentState(error: response.error ?? '创建失败');
      return null;
    }
  }

  void reset() {
    state = CreateDeploymentState();
  }
}

// Providers
final deploymentListProvider =
    StateNotifierProvider<DeploymentListNotifier, DeploymentListState>(
  (ref) => DeploymentListNotifier(),
);

final deploymentDetailProvider =
    StateNotifierProvider<DeploymentDetailNotifier, DeploymentDetailState>(
  (ref) => DeploymentDetailNotifier(),
);

final createDeploymentProvider =
    StateNotifierProvider<CreateDeploymentNotifier, CreateDeploymentState>(
  (ref) => CreateDeploymentNotifier(),
);
