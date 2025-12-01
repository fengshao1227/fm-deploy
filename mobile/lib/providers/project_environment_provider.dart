// mobile/lib/providers/project_environment_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/environment.dart'; // For ProjectEnvironment
import '../services/project_environment_service.dart';

// Provide the ProjectEnvironmentService instance
final projectEnvironmentServiceProvider = Provider((ref) => ProjectEnvironmentService());

// 项目环境配置详情 Provider (family to take ID)
final projectEnvironmentDetailProvider =
    StateNotifierProvider.family<ProjectEnvironmentDetailNotifier, AsyncValue<ProjectEnvironment>, int>(
  (ref, projectEnvironmentId) => ProjectEnvironmentDetailNotifier(ref, projectEnvironmentId),
);

class ProjectEnvironmentDetailNotifier extends StateNotifier<AsyncValue<ProjectEnvironment>> {
  final Ref _ref;
  final int _projectEnvironmentId;
  final ProjectEnvironmentService _service;

  ProjectEnvironmentDetailNotifier(this._ref, this._projectEnvironmentId)
      : _service = _ref.read(projectEnvironmentServiceProvider),
        super(const AsyncValue.loading()) {
    _loadProjectEnvironment();
  }

  Future<void> _loadProjectEnvironment() async {
    state = const AsyncValue.loading();
    final response = await _service.getProjectEnvironment(_projectEnvironmentId);
    if (response.success && response.data != null) {
      state = AsyncValue.data(response.data!);
    } else {
      state = AsyncValue.error(response.error ?? '加载失败', StackTrace.current);
    }
  }

  Future<bool> updateProjectEnvironment(Map<String, dynamic> updateData) async {
    // This provider is for the detail, not for triggering updates from another page's state.
    // However, if the update is successful, we should refresh the data here.
    // The actual update loading state can be managed by the calling widget if needed,
    // or we can add a separate 'update' provider.
    // For simplicity, I'll update the state here to reflect the new data if successful.
    
    // Temporarily set to loading to indicate an action in progress
    // Not AsyncValue.loading() for the entire state, but a part of it.
    // For now, I'll just update the data if successful.
    final response = await _service.updateProjectEnvironment(_projectEnvironmentId, updateData);
    if (response.success && response.data != null) {
      state = AsyncValue.data(response.data!); // Update with new data
      return true;
    } else {
      state = AsyncValue.error(response.error ?? '更新失败', StackTrace.current); // Keep old data
      return false;
    }
  }
}
