import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../models/project.dart';
import '../../providers/project_provider.dart';

/// 项目列表页
class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  final RefreshController _refreshController = RefreshController();
  final TextEditingController _searchController = TextEditingController();
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    // 首次加载
    Future.microtask(() {
      ref.read(projectListProvider.notifier).loadProjects();
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onRefresh() async {
    await ref.read(projectListProvider.notifier).refresh();
    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    await ref.read(projectListProvider.notifier).loadMore();
    final state = ref.read(projectListProvider);
    if (state.hasMore) {
      _refreshController.loadComplete();
    } else {
      _refreshController.loadNoData();
    }
  }

  void _onSearch(String keyword) {
    ref.read(projectListProvider.notifier).setFilter(
          type: _selectedType,
          keyword: keyword.isEmpty ? null : keyword,
        );
  }

  void _onTypeChanged(String? type) {
    setState(() {
      _selectedType = type;
    });
    ref.read(projectListProvider.notifier).setFilter(
          type: type,
          keyword: _searchController.text.isEmpty
              ? null
              : _searchController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('项目列表'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 搜索和筛选
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 搜索框
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索项目名称或标识',
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
                    setState(() {}); // 更新清除按钮显示
                  },
                ),
                const SizedBox(height: 12),

                // 类型筛选
                Row(
                  children: [
                    _FilterChip(
                      label: '全部',
                      isSelected: _selectedType == null,
                      onSelected: (_) => _onTypeChanged(null),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '前端',
                      isSelected: _selectedType == 'frontend',
                      onSelected: (_) => _onTypeChanged('frontend'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '后端',
                      isSelected: _selectedType == 'backend',
                      onSelected: (_) => _onTypeChanged('backend'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 项目列表
          Expanded(
            child: state.isLoading && state.projects.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.error != null && state.projects.isEmpty
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
                    : state.projects.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.folder_off,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '暂无项目',
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
                              itemCount: state.projects.length,
                              itemBuilder: (context, index) {
                                final project = state.projects[index];
                                return _ProjectCard(
                                  project: project,
                                  onTap: () {
                                    context.push('/projects/${project.id}');
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
          context.push('/projects/add');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// 筛选芯片
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      showCheckmark: false,
    );
  }
}

/// 项目卡片
class _ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;

  const _ProjectCard({
    required this.project,
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
                  // 项目图标
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: project.isFrontend
                          ? Colors.blue.shade100
                          : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      project.isFrontend ? Icons.web : Icons.dns,
                      color: project.isFrontend
                          ? Colors.blue.shade700
                          : Colors.green.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 项目名称和标识
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          project.projectKey,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 类型标签
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: project.isFrontend
                          ? Colors.blue.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      project.typeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: project.isFrontend
                            ? Colors.blue.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),

              // 描述
              if (project.description != null &&
                  project.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  project.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],

              // Git 仓库
              if (project.gitRepo != null && project.gitRepo!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.link,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        project.gitRepo!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
