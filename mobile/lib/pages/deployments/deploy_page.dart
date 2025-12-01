import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';
import '../../models/api_response.dart';
import '../../models/deployment.dart';
import '../../models/environment.dart';
import '../../models/environment_url.dart';
import '../../providers/deployment_provider.dart';
import '../../services/deployment_service.dart';
import '../../services/environment_service.dart';
import '../../services/environment_url_service.dart';

/// 部署执行页面
class DeployPage extends ConsumerStatefulWidget {
  final int? projectId;

  const DeployPage({super.key, this.projectId});

  @override
  ConsumerState<DeployPage> createState() => _DeployPageState();
}

class _DeployPageState extends ConsumerState<DeployPage> {
  List<ProjectEnvironment> _configs = [];
  List<EnvironmentUrl> _envUrls = [];
  bool _isLoading = true;
  String? _error;
  int? _selectedConfigId;
  bool _isDeploying = false;
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (widget.projectId == null) {
      setState(() {
        _error = '请选择一个项目';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final envService = EnvironmentService();
      final urlService = EnvironmentUrlService();

      final results = await Future.wait([
        envService.getProjectEnvironments(widget.projectId!),
        urlService.getAllUrls(),
      ]);

      final envResponse = results[0] as ApiResponse<List<ProjectEnvironment>>;
      final urlResponse = results[1] as ApiResponse<List<EnvironmentUrl>>;

      if (envResponse.success && envResponse.data != null) {
        setState(() {
          _configs = envResponse.data!.where((c) => c.enabled).toList();
          if (urlResponse.success && urlResponse.data != null) {
            _envUrls = urlResponse.data!;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = envResponse.error ?? '加载失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '发生错误: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDeploy() async {
    if (_selectedConfigId == null) {
      Fluttertoast.showToast(msg: '请选择部署环境');
      return;
    }

    setState(() => _isDeploying = true);

    try {
      final selectedConfig = _configs.firstWhere((c) => c.id == _selectedConfigId);
      final envUrl = _urlController.text.trim();

      // Show confirmation dialog before actual deploy
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认更新？'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('项目: ${selectedConfig.project?.name ?? '未知'}'),
              Text('环境: ${selectedConfig.environment?.name ?? '未知'}'),
              Text('分支: ${selectedConfig.branch}'),
              Text('模式: ${selectedConfig.deployMode ?? '未知'}'),
              if (envUrl.isNotEmpty) Text('API 地址: $envUrl'),
              const SizedBox(height: 10),
              const Text('⚠️ 请确认以上信息无误'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => ctx.pop(false), // Cancel
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => ctx.pop(true), // Confirm
              child: const Text('确认更新'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        setState(() => _isDeploying = false); // Important to reset state if not confirmed
        return; // If not confirmed, do nothing
      }

      final deployment = await ref
          .read(createDeploymentProvider.notifier)
          .createDeployment(
            _selectedConfigId!,
            envUrl: envUrl.isNotEmpty ? envUrl : null,
          );

      if (deployment == null) {
        if (mounted) {
          setState(() => _isDeploying = false);
          final error = ref.read(createDeploymentProvider).error;
          Fluttertoast.showToast(msg: error ?? '创建失败');
        }
        return;
      }

      // 轮询部署状态
      final service = DeploymentService();
      bool isFinished = false;
      Deployment? resultDeployment;
      
      // 最多轮询5分钟
      final startTime = DateTime.now();
      
      while (!isFinished && mounted) {
        if (DateTime.now().difference(startTime).inMinutes >= 5) {
          break; // 超时
        }
        
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) break;

        final response = await service.getDeployment(deployment.id);
        if (response.success && response.data != null) {
          final d = response.data!;
          if (d.status == DeploymentStatus.success || 
              d.status == DeploymentStatus.failed) {
            isFinished = true;
            resultDeployment = d;
          }
        }
      }

      if (mounted) {
        setState(() => _isDeploying = false);

        if (resultDeployment?.status == DeploymentStatus.success) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('更新成功'),
              content: const Text('项目已成功更新到最新提交。'),
              actions: [
                TextButton(
                  onPressed: () {
                    context.pop(); // 关闭对话框
                    context.go(AppRoutes.deployments); // 跳转到更新记录
                  },
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('更新失败'),
              content: Text(resultDeployment?.errorMessage ?? '未知错误或超时'),
              actions: [
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('关闭'),
                ),
                FilledButton(
                  onPressed: () {
                    context.pop();
                    context.push('/deployments/${deployment.id}');
                  },
                  child: const Text('查看日志'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeploying = false);
        Fluttertoast.showToast(msg: '发生错误: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('更新项目'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
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
                        _error!,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadData,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _configs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.settings_suggest_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '该项目暂无可用的环境配置',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '请联系管理员配置部署环境',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 提示信息
                          Card(
                            color: Colors.blue.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '选择要更新的目标环境，点击按钮开始执行',
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 选择环境标题
                          Text(
                            '选择环境',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),

                          // 环境配置列表
                          Expanded(
                            child: ListView.builder(
                              itemCount: _configs.length,
                              itemBuilder: (context, index) {
                                final config = _configs[index];
                                final isSelected =
                                    _selectedConfigId == config.id;
                                return _ConfigCard(
                                  config: config,
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedConfigId = config.id;
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // API 地址输入/选择
                          Autocomplete<String>(
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text == '') {
                                return _envUrls.map((e) => e.url);
                              }
                              return _envUrls
                                  .where((e) => e.url.contains(textEditingValue.text))
                                  .map((e) => e.url);
                            },
                            onSelected: (String selection) {
                              _urlController.text = selection;
                            },
                            fieldViewBuilder: (
                              BuildContext context,
                              TextEditingController fieldTextEditingController,
                              FocusNode fieldFocusNode,
                              VoidCallback onFieldSubmitted,
                            ) {
                              // Sync internal controller with field controller
                              if (_urlController.text != fieldTextEditingController.text) {
                                fieldTextEditingController.text = _urlController.text;
                              }
                              // Listen for changes
                              fieldTextEditingController.addListener(() {
                                _urlController.text = fieldTextEditingController.text;
                              });
                              
                              return TextField(
                                controller: fieldTextEditingController,
                                focusNode: fieldFocusNode,
                                decoration: const InputDecoration(
                                  labelText: 'API 地址 (可选)',
                                  hintText: '输入或选择 API 地址',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.link),
                                ),
                              );
                            },
                          ),

                          // 部署按钮
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isDeploying || _selectedConfigId == null
                                  ? null
                                  : _handleDeploy,
                              icon: _isDeploying
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.sync),
                              label: Text(_isDeploying ? '正在更新...' : '开始更新'),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

/// 配置卡片
class _ConfigCard extends StatelessWidget {
  final ProjectEnvironment config;
  final bool isSelected;
  final VoidCallback onTap;

  const _ConfigCard({
    required this.config,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 选中标记
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),

              // 环境信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.dns,
                          size: 16,
                          color: Colors.purple.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          config.environment?.name ?? '未知环境',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 分支
                    Row(
                      children: [
                        Icon(
                          Icons.account_tree,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '分支: ${config.branch}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // 部署路径
                    Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            config.deployPath,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}