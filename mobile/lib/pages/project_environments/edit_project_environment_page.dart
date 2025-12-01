// mobile/lib/pages/project_environments/edit_project_environment_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import '../../models/environment.dart';
import '../../providers/project_environment_provider.dart';

class EditProjectEnvironmentPage extends ConsumerStatefulWidget {
  final int projectEnvironmentId;

  const EditProjectEnvironmentPage({super.key, required this.projectEnvironmentId});

  @override
  ConsumerState<EditProjectEnvironmentPage> createState() => _EditProjectEnvironmentPageState();
}

class _EditProjectEnvironmentPageState extends ConsumerState<EditProjectEnvironmentPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _branchController;
  late TextEditingController _deployPathController;
  late TextEditingController _buildCommandController;
  late TextEditingController _preDeployCommandController;
  late TextEditingController _postDeployCommandController;
  bool _enabled = true;
  bool _isSaving = false;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _branchController = TextEditingController();
    _deployPathController = TextEditingController();
    _buildCommandController = TextEditingController();
    _preDeployCommandController = TextEditingController();
    _postDeployCommandController = TextEditingController();
  }

  void _initializeControllers(ProjectEnvironment projectEnv) {
    if (!_hasInitialized) {
      _branchController.text = projectEnv.branch;
      _deployPathController.text = projectEnv.deployPath;
      _buildCommandController.text = projectEnv.buildCommand ?? '';
      _preDeployCommandController.text = projectEnv.preDeployCommand ?? '';
      _postDeployCommandController.text = projectEnv.postDeployCommand ?? '';
      _enabled = projectEnv.enabled;
      _hasInitialized = true;
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final updateData = {
      'branch': _branchController.text.trim(),
      'deployPath': _deployPathController.text.trim(),
      'buildCommand': _buildCommandController.text.trim().isEmpty
          ? null
          : _buildCommandController.text.trim(),
      'preDeployCommand': _preDeployCommandController.text.trim().isEmpty
          ? null
          : _preDeployCommandController.text.trim(),
      'postDeployCommand': _postDeployCommandController.text.trim().isEmpty
          ? null
          : _postDeployCommandController.text.trim(),
      'enabled': _enabled,
    };

    final success = await ref
        .read(projectEnvironmentDetailProvider(widget.projectEnvironmentId).notifier)
        .updateProjectEnvironment(updateData);

    setState(() => _isSaving = false);

    if (success && mounted) {
      Fluttertoast.showToast(msg: '保存成功');
      context.pop(true); // Return true to indicate success
    } else {
      Fluttertoast.showToast(msg: '保存失败');
    }
  }

  @override
  void dispose() {
    _branchController.dispose();
    _deployPathController.dispose();
    _buildCommandController.dispose();
    _preDeployCommandController.dispose();
    _postDeployCommandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncProjectEnv = ref.watch(projectEnvironmentDetailProvider(widget.projectEnvironmentId));

    return asyncProjectEnv.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('编辑环境配置')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('编辑环境配置')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text('加载失败: $error', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(projectEnvironmentDetailProvider(widget.projectEnvironmentId)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      data: (projectEnv) {
        // Initialize controllers with fetched data
        _initializeControllers(projectEnv);

        return Scaffold(
          appBar: AppBar(
            title: const Text('编辑环境配置'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (projectEnv.project != null)
                    Text(
                      '项目: ${projectEnv.project!.name}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  const SizedBox(height: 8),
                  if (projectEnv.environment != null)
                    Text(
                      '环境: ${projectEnv.environment!.name}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _branchController,
                    decoration: const InputDecoration(
                      labelText: '部署分支',
                      hintText: '常用: master / develop / main',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '分支名称不能为空';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _deployPathController,
                    decoration: const InputDecoration(
                      labelText: '部署路径',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '部署路径不能为空';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _buildCommandController,
                    decoration: const InputDecoration(
                      labelText: '构建命令 (可选)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _preDeployCommandController,
                    decoration: const InputDecoration(
                      labelText: '部署前命令 (可选)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _postDeployCommandController,
                    decoration: const InputDecoration(
                      labelText: '部署后命令 (可选)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('是否启用'),
                    value: _enabled,
                    onChanged: (value) {
                      setState(() {
                        _enabled = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      child: Text(_isSaving ? '保存中...' : '保存'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
