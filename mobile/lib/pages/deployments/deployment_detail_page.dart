import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../models/deployment.dart';
import '../../providers/deployment_provider.dart';

/// 部署详情页
class DeploymentDetailPage extends ConsumerStatefulWidget {
  final int deploymentId;

  const DeploymentDetailPage({super.key, required this.deploymentId});

  @override
  ConsumerState<DeploymentDetailPage> createState() =>
      _DeploymentDetailPageState();
}

class _DeploymentDetailPageState extends ConsumerState<DeploymentDetailPage> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(deploymentDetailProvider.notifier)
          .loadDeployment(widget.deploymentId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消部署'),
        content: const Text('确定要取消该部署任务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('否'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('是'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(deploymentDetailProvider.notifier)
          .cancel(widget.deploymentId);
      if (success) {
        Fluttertoast.showToast(msg: '已取消部署');
      } else {
        Fluttertoast.showToast(msg: '取消失败');
      }
    }
  }

  Future<void> _handleRollback() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('回滚部署'),
        content: const Text('确定要回滚到该部署版本吗？这将创建一个新的部署任务。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定回滚'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(deploymentDetailProvider.notifier)
          .rollback(widget.deploymentId);
      if (success) {
        Fluttertoast.showToast(msg: '回滚任务已创建');
        ref.read(deploymentListProvider.notifier).refresh();
      } else {
        Fluttertoast.showToast(msg: '回滚失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deploymentDetailProvider);

    // 自动滚动到底部
    ref.listen(deploymentDetailProvider, (previous, next) {
      if (previous?.logs.length != next.logs.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('部署详情'),
        actions: [
          if (state.deployment != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'cancel') {
                  _handleCancel();
                } else if (value == 'rollback') {
                  _handleRollback();
                }
              },
              itemBuilder: (context) {
                final deployment = state.deployment!;
                return [
                  if (deployment.status.isPending ||
                      deployment.status.isRunning)
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Row(
                        children: [
                          Icon(Icons.cancel, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('取消部署'),
                        ],
                      ),
                    ),
                  if (deployment.status.isSuccess)
                    const PopupMenuItem(
                      value: 'rollback',
                      child: Row(
                        children: [
                          Icon(Icons.history, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('回滚到此版本'),
                        ],
                      ),
                    ),
                ];
              },
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
              : state.deployment == null
                  ? const Center(child: Text('部署记录不存在'))
                  : Column(
                      children: [
                        // 部署信息卡片
                        _buildInfoSection(state.deployment!),

                        // 日志区域
                        Expanded(
                          child: _buildLogsSection(state),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildInfoSection(Deployment deployment) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // 状态图标
              _buildStatusIcon(deployment.status),
              const SizedBox(width: 12),

              // 项目和环境
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
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // 状态标签
              _buildStatusBadge(deployment.status),
            ],
          ),

          const SizedBox(height: 12),

          // 其他信息
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (deployment.shortCommitHash != null)
                _buildInfoChip(
                  Icons.commit,
                  deployment.shortCommitHash!,
                ),
              if (deployment.user != null)
                _buildInfoChip(
                  Icons.person_outline,
                  deployment.user!.name,
                ),
              if (deployment.durationFormatted != null)
                _buildInfoChip(
                  Icons.timer_outlined,
                  deployment.durationFormatted!,
                ),
            ],
          ),

          // 提交信息
          if (deployment.commitMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                deployment.commitMessage!,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                ),
              ),
            ),
          ],

          // 错误信息
          if (deployment.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      deployment.errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcon(DeploymentStatus status) {
    IconData icon;
    Color color;

    switch (status) {
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildStatusBadge(DeploymentStatus status) {
    Color color;
    switch (status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 13,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildLogsSection(DeploymentDetailState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 日志标题栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text(
                '部署日志',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              // 自动滚动开关
              Row(
                children: [
                  Text(
                    '自动滚动',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Switch(
                    value: _autoScroll,
                    onChanged: (value) {
                      setState(() => _autoScroll = value);
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ],
          ),
        ),

        // 日志列表
        Expanded(
          child: state.logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (state.deployment?.status.isPending == true ||
                          state.deployment?.status.isRunning == true) ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text('等待日志输出...'),
                      ] else ...[
                        Icon(
                          Icons.article_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无日志',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                )
              : Container(
                  color: Colors.grey.shade900,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: state.logs.length,
                    itemBuilder: (context, index) {
                      final log = state.logs[index];
                      return _LogLine(log: log);
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

/// 日志行
class _LogLine extends StatelessWidget {
  final DeploymentLog log;

  const _LogLine({required this.log});

  @override
  Widget build(BuildContext context) {
    Color textColor;
    switch (log.logType) {
      case 'error':
      case 'stderr':
        textColor = Colors.red.shade300;
        break;
      case 'info':
        textColor = Colors.blue.shade300;
        break;
      default:
        textColor = Colors.grey.shade300;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间戳
          Text(
            _formatTime(log.timestamp),
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          // 日志内容
          Expanded(
            child: Text(
              log.message,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
