import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../router/app_router.dart';
import '../../services/websocket_service.dart';

/// 首页
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _wsService = WebSocketService();
  bool _wsConnected = false;
  StreamSubscription<bool>? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _initWebSocket();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  void _initWebSocket() {
    // 先获取当前连接状态
    _wsConnected = _wsService.isConnected;

    _wsSubscription = _wsService.connectionStream.listen((connected) {
      if (mounted) {
        setState(() => _wsConnected = connected);
      }
    });

    // 连接 WebSocket（如果已连接会自动跳过）
    _wsService.connect();

    // 触发当前状态更新
    _wsService.emitCurrentStatus();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FM Deploy'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(authProvider.notifier).refreshUser();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 欢迎卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          user?.name.isNotEmpty == true
                              ? user!.name[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '欢迎回来',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.name ?? '用户',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: user?.isAdmin == true
                                    ? Colors.orange.shade100
                                    : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                user?.isAdmin == true ? '管理员' : '开发者',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: user?.isAdmin == true
                                      ? Colors.orange.shade800
                                      : Colors.blue.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 快捷操作
              Text(
                '快捷操作',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              // 操作卡片网格
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _QuickActionCard(
                    icon: Icons.folder,
                    title: '项目管理',
                    subtitle: '查看所有项目',
                    color: Colors.blue,
                    onTap: () => context.go(AppRoutes.projects),
                  ),
                  _QuickActionCard(
                    icon: Icons.dns,
                    title: '环境管理',
                    subtitle: '管理服务器环境',
                    color: Colors.purple,
                    onTap: () => context.push(AppRoutes.environments),
                  ),
                  _QuickActionCard(
                    icon: Icons.rocket_launch,
                    title: '部署记录',
                    subtitle: '查看部署历史',
                    color: Colors.green,
                    onTap: () => context.go(AppRoutes.deployments),
                  ),
                  _QuickActionCard(
                    icon: Icons.settings,
                    title: '系统设置',
                    subtitle: '个人信息管理',
                    color: Colors.orange,
                    onTap: () => context.go(AppRoutes.settings),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 系统状态
              Text(
                '系统状态',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _StatusItem(
                        icon: Icons.cloud_done,
                        title: 'API 服务',
                        status: '正常运行',
                        isOk: true,
                      ),
                      const Divider(),
                      _StatusItem(
                        icon: Icons.wifi,
                        title: 'WebSocket',
                        status: _wsConnected ? '已连接' : '未连接',
                        isOk: _wsConnected,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 快捷操作卡片
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 状态项
class _StatusItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final bool isOk;

  const _StatusItem({
    required this.icon,
    required this.title,
    required this.status,
    required this.isOk,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isOk ? Colors.green.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: isOk ? Colors.green.shade800 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
