// lib/providers/version_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/backup_version.dart';
import '../services/version_service.dart';

// Provide the VersionService instance
final versionServiceProvider = Provider((ref) => VersionService());

// 版本列表 Provider
// 参数: projectEnvironmentId
final versionsProvider = FutureProvider.family<List<BackupVersion>, int>(
  (ref, projectEnvironmentId) async {
    final versionService = ref.read(versionServiceProvider);
    final response = await versionService.getVersions(projectEnvironmentId);
    if (response.success && response.data != null) {
      return response.data!;
    }
    throw Exception(response.error ?? '获取版本列表失败');
  },
);

// 回滚状态 Provider
final rollbackStateProvider = StateNotifierProvider<RollbackNotifier, AsyncValue<void>>(
  (ref) => RollbackNotifier(ref),
);

class RollbackNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  RollbackNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> rollback(int snapshotId) async {
    state = const AsyncValue.loading();
    try {
      final versionService = _ref.read(versionServiceProvider);
      final response = await versionService.rollbackToVersion(snapshotId);
      if (response.success) {
        state = const AsyncValue.data(null); // Success
      } else {
        throw Exception(response.error ?? '回滚失败');
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
