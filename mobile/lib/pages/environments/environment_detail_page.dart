import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import '../../models/environment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/environment_provider.dart';

/// 环境详情页
class EnvironmentDetailPage extends ConsumerStatefulWidget {
  final int environmentId;

  const EnvironmentDetailPage({super.key, required this.environmentId});

  @override
  ConsumerState<EnvironmentDetailPage> createState() =>
      _EnvironmentDetailPageState();
}

class _EnvironmentDetailPageState
    extends ConsumerState<EnvironmentDetailPage> {
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(environmentDetailProvider.notifier)
          .loadEnvironment(widget.environmentId);
    });
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);

    final result = await ref
        .read(environmentDetailProvider.notifier)
        .testConnection(widget.environmentId);

    setState(() => _isTesting = false);

    if (result != null) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  result.connected ? Icons.check_circle : Icons.error,
                  color: result.connected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(result.connected ? '连接成功' : '连接失败'),
              ],
            ),
            content: Text(result.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } else {
      Fluttertoast.showToast(msg: '测试连接失败');
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除该环境吗？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(environmentDetailProvider.notifier)
          .deleteEnvironment(widget.environmentId);
      if (success && mounted) {
        Fluttertoast.showToast(msg: '删除成功');
        context.pop();
        ref.read(environmentListProvider.notifier).refresh();
      } else {
        Fluttertoast.showToast(msg: '删除失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(environmentDetailProvider);
    final authState = ref.watch(authProvider);
    final isAdmin = authState.user?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('环境详情'),
        actions: [
          if (isAdmin && state.environment != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _confirmDelete();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('删除环境', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.error!,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : state.environment == null
                  ? const Center(child: Text('环境不存在'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 基本信息卡片
                          _buildInfoCard(state.environment!),
                          const SizedBox(height: 16),

                          // SSH 连接信息卡片
                          _buildSshCard(state.environment!),
                          const SizedBox(height: 16),

                          // 测试连接按钮
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isTesting ? null : _testConnection,
                              icon: _isTesting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.wifi_tethering),
                              label: Text(_isTesting ? '测试中...' : '测试 SSH 连接'),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 关联的项目配置
                          if (state.environment!.projectEnvironments != null &&
                              state.environment!.projectEnvironments!
                                  .isNotEmpty) ...[
                            Text(
                              '关联的项目配置',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            ...state.environment!.projectEnvironments!
                                .map((pe) => _buildProjectConfigCard(pe)),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _buildInfoCard(Environment environment) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.dns,
                    color: Colors.purple.shade700,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        environment.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      if (environment.description != null &&
                          environment.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            environment.description!,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSshCard(Environment environment) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SSH 连接信息',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('主机', environment.sshHost),
            _buildInfoRow('端口', environment.sshPort.toString()),
            _buildInfoRow('用户', environment.sshUser),
            if (environment.sshKeyPath != null)
              _buildInfoRow('密钥路径', environment.sshKeyPath!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectConfigCard(ProjectEnvironment projectEnv) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: projectEnv.project?.isFrontend == true
                ? Colors.blue.shade100
                : Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            projectEnv.project?.isFrontend == true ? Icons.web : Icons.dns,
            color: projectEnv.project?.isFrontend == true
                ? Colors.blue.shade700
                : Colors.green.shade700,
            size: 20,
          ),
        ),
        title: Text(projectEnv.project?.name ?? '未知项目'),
        subtitle: Text('分支: ${projectEnv.branch}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                    projectEnv.enabled ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                projectEnv.enabled ? '已启用' : '已禁用',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      projectEnv.enabled ? Colors.green.shade700 : Colors.grey.shade600,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () {
                context.push('/project-environments/${projectEnv.id}/edit'); // New route
              },
            ),
          ],
        ),
      ),
    );
  }
}
