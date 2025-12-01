import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../models/deployment.dart';
import '../../providers/deployment_provider.dart';

/// 部署记录列表页
class DeploymentsPage extends ConsumerStatefulWidget {
  const DeploymentsPage({super.key});

  @override
  ConsumerState<DeploymentsPage> createState() => _DeploymentsPageState();
}

class _DeploymentsPageState extends ConsumerState<DeploymentsPage> {
  final RefreshController _refreshController = RefreshController();
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(deploymentListProvider.notifier).loadDeployments();
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  void _onRefresh() async {
    await ref.read(deploymentListProvider.notifier).refresh();
    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    await ref.read(deploymentListProvider.notifier).loadMore();
    final state = ref.read(deploymentListProvider);
    if (state.hasMore) {
      _refreshController.loadComplete();
    } else {
      _refreshController.loadNoData();
    }
  }

  void _onStatusChanged(String? status) {
    setState(() => _selectedStatus = status);
    ref.read(deploymentListProvider.notifier).setStatusFilter(status);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deploymentListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('部署记录'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 状态筛选
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _StatusFilterChip(
                    label: '全部',
                    isSelected: _selectedStatus == null,
                    onSelected: (_) => _onStatusChanged(null),
                  ),
                  const SizedBox(width: 8),
                  _StatusFilterChip(
                    label: '等待中',
                    isSelected: _selectedStatus == 'pending',
                    onSelected: (_) => _onStatusChanged('pending'),
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _StatusFilterChip(
                    label: '执行中',
                    isSelected: _selectedStatus == 'running',
                    onSelected: (_) => _onStatusChanged('running'),
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _StatusFilterChip(
                    label: '成功',
                    isSelected: _selectedStatus == 'success',
                    onSelected: (_) => _onStatusChanged('success'),
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _StatusFilterChip(
                    label: '失败',
                    isSelected: _selectedStatus == 'failed',
                    onSelected: (_) => _onStatusChanged('failed'),
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ),

          // 部署列表
          Expanded(
            child: state.isLoading && state.deployments.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.error != null && state.deployments.isEmpty
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
                              onPressed: _onRefresh,
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      )
                    : state.deployments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.rocket_launch_outlined,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '暂无部署记录',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : SmartRefresher(
                            controller: _refreshController,
                            enablePullDown: true,
                            enablePullUp: true,
                            onRefresh: _onRefresh,
                            onLoading: _onLoading,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: state.deployments.length,
                              itemBuilder: (context, index) {
                                final deployment = state.deployments[index];
                                return _DeploymentCard(
                                  deployment: deployment,
                                  onTap: () {
                                    context.push('/deployments/${deployment.id}');
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

/// 状态筛选芯片
class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;
  final Color? color;

  const _StatusFilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      showCheckmark: false,
      selectedColor: color?.withAlpha(51),
      labelStyle: TextStyle(
        color: isSelected ? color : null,
      ),
    );
  }
}

/// 部署卡片
class _DeploymentCard extends StatelessWidget {
  final Deployment deployment;
  final VoidCallback onTap;

  const _DeploymentCard({
    required this.deployment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 状态图标
                  _buildStatusIcon(),
                  const SizedBox(width: 12),

                  // 项目和环境信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deployment.project?.name ?? '未知项目',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          deployment.environment?.name ?? '未知环境',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 状态标签
                  _buildStatusBadge(),
                ],
              ),

              const SizedBox(height: 12),

              // 提交信息
              if (deployment.commitMessage != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.commit,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    if (deployment.shortCommitHash != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          deployment.shortCommitHash!,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        deployment.commitMessage!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // 底部信息
              Row(
                children: [
                  // 操作人
                  if (deployment.user != null) ...[
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      deployment.user!.name,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],

                  // 执行时间
                  if (deployment.durationFormatted != null) ...[
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      deployment.durationFormatted!,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],

                  // 创建时间
                  if (deployment.createdAt != null) ...[
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(deployment.createdAt!),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color;

    switch (deployment.status) {
      case DeploymentStatus.pending:
        icon = Icons.schedule;
        color = Colors.orange;
        break;
      case DeploymentStatus.running:
        icon = Icons.sync;
        color = Colors.blue;
        break;
      case DeploymentStatus.success:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case DeploymentStatus.failed:
        icon = Icons.error;
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    switch (deployment.status) {
      case DeploymentStatus.pending:
        color = Colors.orange;
        break;
      case DeploymentStatus.running:
        color = Colors.blue;
        break;
      case DeploymentStatus.success:
        color = Colors.green;
        break;
      case DeploymentStatus.failed:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        deployment.status.label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
