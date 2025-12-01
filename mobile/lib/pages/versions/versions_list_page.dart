// mobile/lib/pages/versions/versions_list_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // Import go_router
import '../../providers/version_provider.dart';
import '../../models/backup_version.dart';

class VersionsListPage extends ConsumerStatefulWidget {
  final int projectEnvironmentId;

  const VersionsListPage({super.key, required this.projectEnvironmentId});

  @override
  ConsumerState<VersionsListPage> createState() => _VersionsListPageState();
}

class _VersionsListPageState extends ConsumerState<VersionsListPage> {
  @override
  Widget build(BuildContext context) {
    final versionsAsyncValue = ref.watch(versionsProvider(widget.projectEnvironmentId));
    final rollbackNotifier = ref.read(rollbackStateProvider.notifier);

    // Listen for rollback state changes
    ref.listen<AsyncValue<void>>(rollbackStateProvider, (previous, next) {
      next.whenOrNull(
        data: (_) {
          // Rollback successful
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('回滚成功'),
              content: const Text('已成功回滚到指定版本。'),
              actions: [
                TextButton(
                  onPressed: () {
                    ctx.pop(); // Close dialog
                    ref.invalidate(versionsProvider(widget.projectEnvironmentId)); // Refresh versions list
                  },
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        },
        error: (e, st) {
          // Rollback failed
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('回滚失败'),
              content: Text('回滚失败: ${e.toString()}'),
              actions: [
                TextButton(
                  onPressed: () => ctx.pop(),
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: versionsAsyncValue.when(
          data: (versions) => Text('历史版本 (共 ${versions.length} 个)'),
          loading: () => const Text('历史版本'),
          error: (error, stack) => const Text('历史版本'),
        ),
      ),
      body: versionsAsyncValue.when(
        data: (versions) {
          if (versions.isEmpty) {
            return const Center(child: Text('暂无历史版本可回滚'));
          }
          return ListView.builder(
            itemCount: versions.length,
            itemBuilder: (context, index) {
              final version = versions[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📦 ${version.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(version.formattedTime),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: FilledButton( // Changed to FilledButton for prototype consistency
                          onPressed: ref.watch(rollbackStateProvider).isLoading
                              ? null // Disable button if rollback is in progress
                              : () {
                                  _showRollbackConfirmDialog(context, version, rollbackNotifier);
                                },
                          child: const Text('回滚'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('加载失败: $error')),
      ),
    );
  }

  void _showRollbackConfirmDialog(BuildContext context, BackupVersion version, RollbackNotifier notifier) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('确认回滚？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('即将回滚到版本:'),
            Text(
              version.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('⚠️ 当前版本将被备份，可再次回滚'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(), // Cancel
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ctx.pop(); // Close confirm dialog
              notifier.rollback(version.id); // Trigger rollback
            },
            child: const Text('确认回滚'),
          ),
        ],
      ),
    );
  }
}
