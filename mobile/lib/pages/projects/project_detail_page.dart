import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';

/// 项目详情页
class ProjectDetailPage extends ConsumerStatefulWidget {
  final int projectId;

  const ProjectDetailPage({super.key, required this.projectId});

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(projectDetailProvider.notifier).loadProject(widget.projectId);
    });
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个项目吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(projectDetailProvider.notifier)
          .deleteProject(widget.projectId);

      if (success && mounted) {
        Fluttertoast.showToast(msg: '项目已删除');
        // 刷新列表
        ref.read(projectListProvider.notifier).refresh();
        context.pop();
      } else {
        Fluttertoast.showToast(msg: '删除失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectDetailProvider);
    final authState = ref.watch(authProvider);
    final isAdmin = authState.user?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('项目详情'),
        actions: [
          if (isAdmin && state.project != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _handleDelete();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('删除项目', style: TextStyle(color: Colors.red)),
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
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          ref
                              .read(projectDetailProvider.notifier)
                              .loadProject(widget.projectId);
                        },
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : state.project == null
                  ? const Center(child: Text('项目不存在'))
                  : RefreshIndicator(
                      onRefresh: () async {
                        await ref
                            .read(projectDetailProvider.notifier)
                            .loadProject(widget.projectId);
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 基本信息卡片
                            _InfoCard(
                              title: '基本信息',
                              children: [
                                _InfoItem(
                                  label: '项目名称',
                                  value: state.project!.name,
                                ),
                                _InfoItem(
                                  label: '项目标识',
                                  value: state.project!.projectKey,
                                ),
                                _InfoItem(
                                  label: '项目类型',
                                  value: state.project!.typeLabel,
                                  valueWidget: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: state.project!.isFrontend
                                          ? Colors.blue.shade100
                                          : Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      state.project!.typeLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: state.project!.isFrontend
                                            ? Colors.blue.shade700
                                            : Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                                if (state.project!.description != null &&
                                    state.project!.description!.isNotEmpty)
                                  _InfoItem(
                                    label: '项目描述',
                                    value: state.project!.description!,
                                  ),
                                if (state.project!.gitRepo != null &&
                                    state.project!.gitRepo!.isNotEmpty)
                                  _InfoItem(
                                    label: 'Git 仓库',
                                    value: state.project!.gitRepo!,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // 环境配置卡片
                            _InfoCard(
                              title: '环境配置',
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (state.project!.projectEnvironments?.isNotEmpty == true)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        '${state.project!.projectEnvironments!.length} 个环境',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () {
                                      context.push(
                                        '/projects/${widget.projectId}/environments/add',
                                      );
                                    },
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    tooltip: '添加环境配置',
                                  ),
                                ],
                              ),
                              children: state.project!.projectEnvironments
                                          ?.isNotEmpty ==
                                      true
                                  ? state.project!.projectEnvironments!
                                      .map((env) => _EnvironmentItem(env: env))
                                      .toList()
                                  : [
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Center(
                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons.cloud_off,
                                                size: 32,
                                                color: Colors.grey.shade400,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                '暂无环境配置',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                            ),
                            const SizedBox(height: 16),

                            // 部署按钮
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: state.project!.projectEnvironments
                                            ?.isNotEmpty ==
                                        true
                                    ? () {
                                        context.push(
                                          '/deploy?projectId=${widget.projectId}',
                                        );
                                      }
                                    : null,
                                icon: const Icon(Icons.sync),
                                label: const Text('更新项目到最新提交'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }
}

/// 信息卡片
class _InfoCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

/// 信息项
class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final Widget? valueWidget;

  const _InfoItem({
    required this.label,
    required this.value,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: valueWidget ??
                Text(
                  value,
                  style: const TextStyle(fontSize: 14),
                ),
          ),
        ],
      ),
    );
  }
}

/// 环境配置项
class _EnvironmentItem extends StatelessWidget {
  final dynamic env;

  const _EnvironmentItem({required this.env});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.cloud,
                  size: 16,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                env.environment?.name ?? '未知环境',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _EnvInfoRow(
            icon: Icons.folder,
            label: '部署路径',
            value: env.deployPath,
          ),
          _EnvInfoRow(
            icon: Icons.account_tree,
            label: '分支',
            value: env.branch,
          ),
          if (env.buildCommand != null && env.buildCommand.isNotEmpty)
            _EnvInfoRow(
              icon: Icons.terminal,
              label: '构建命令',
              value: env.buildCommand,
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                context.push('/project-environments/${env.id}/versions'); // New route
              },
              icon: const Icon(Icons.history),
              label: const Text('历史版本'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 环境信息行
class _EnvInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _EnvInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
