import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../models/environment.dart';
import '../../providers/environment_provider.dart';

/// 环境列表页
class EnvironmentsPage extends ConsumerStatefulWidget {
  const EnvironmentsPage({super.key});

  @override
  ConsumerState<EnvironmentsPage> createState() => _EnvironmentsPageState();
}

class _EnvironmentsPageState extends ConsumerState<EnvironmentsPage> {
  final RefreshController _refreshController = RefreshController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(environmentListProvider.notifier).loadEnvironments();
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onRefresh() async {
    await ref.read(environmentListProvider.notifier).refresh();
    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    await ref.read(environmentListProvider.notifier).loadMore();
    final state = ref.read(environmentListProvider);
    if (state.hasMore) {
      _refreshController.loadComplete();
    } else {
      _refreshController.loadNoData();
    }
  }

  void _onSearch(String keyword) {
    ref.read(environmentListProvider.notifier).search(
          keyword.isEmpty ? null : keyword,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(environmentListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('环境管理'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索环境名称',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
              ),
              onSubmitted: _onSearch,
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),

          // 环境列表
          Expanded(
            child: state.isLoading && state.environments.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.error != null && state.environments.isEmpty
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
                    : state.environments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.dns_outlined,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '暂无环境',
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
                              itemCount: state.environments.length,
                              itemBuilder: (context, index) {
                                final env = state.environments[index];
                                return _EnvironmentCard(
                                  environment: env,
                                  onTap: () {
                                    context.push('/environments/${env.id}');
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/environments/add');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// 环境卡片
class _EnvironmentCard extends StatelessWidget {
  final Environment environment;
  final VoidCallback onTap;

  const _EnvironmentCard({
    required this.environment,
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
                  // 图标
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.dns,
                      color: Colors.purple.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 名称
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          environment.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${environment.sshUser}@${environment.sshHost}:${environment.sshPort}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 箭头
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),

              // 描述
              if (environment.description != null &&
                  environment.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  environment.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
