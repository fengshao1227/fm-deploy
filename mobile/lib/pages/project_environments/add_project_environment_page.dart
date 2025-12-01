// mobile/lib/pages/project_environments/add_project_environment_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import '../../models/environment.dart';
import '../../providers/environment_provider.dart';
import '../../providers/project_provider.dart';

class AddProjectEnvironmentPage extends ConsumerStatefulWidget {
  final int projectId;

  const AddProjectEnvironmentPage({super.key, required this.projectId});

  @override
  ConsumerState<AddProjectEnvironmentPage> createState() =>
      _AddProjectEnvironmentPageState();
}

class _AddProjectEnvironmentPageState
    extends ConsumerState<AddProjectEnvironmentPage> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedEnvId;
  final _branchController = TextEditingController(text: 'master');
  String _deployMode = 'push';
  final _deployPathController = TextEditingController();
  final _buildOutputPathController = TextEditingController(text: 'dist');
  final _buildCommandController = TextEditingController(text: 'npm run build');
  final _preDeployController = TextEditingController();
  final _postDeployController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // 加载所有环境用于下拉选择
    Future.microtask(() {
      ref.read(allEnvironmentsProvider.notifier).loadAll();
    });
  }

  @override
  void dispose() {
    _branchController.dispose();
    _deployPathController.dispose();
    _buildOutputPathController.dispose();
    _buildCommandController.dispose();
    _preDeployController.dispose();
    _postDeployController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEnvId == null) {
      Fluttertoast.showToast(msg: '请选择环境');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await ref
          .read(projectEnvironmentsProvider.notifier)
          .createConfig(
            widget.projectId,
            environmentId: _selectedEnvId!,
            deployPath: _deployPathController.text.trim(),
            branch: _branchController.text.trim(),
            deployMode: _deployMode,
            buildOutputPath: _buildOutputPathController.text.trim(),
            buildCommand: _buildCommandController.text.trim().isEmpty
                ? null
                : _buildCommandController.text.trim(),
            preDeployCommand: _preDeployController.text.trim().isEmpty
                ? null
                : _preDeployController.text.trim(),
            postDeployCommand: _postDeployController.text.trim().isEmpty
                ? null
                : _postDeployController.text.trim(),
          );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (response.success) {
          Fluttertoast.showToast(msg: '配置已添加');
          // 刷新项目详情以显示新配置
          ref.read(projectDetailProvider.notifier).loadProject(widget.projectId);
          context.pop();
        } else {
          Fluttertoast.showToast(msg: response.error ?? '添加失败');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        Fluttertoast.showToast(msg: '发生错误: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allEnvs = ref.watch(allEnvironmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加环境配置'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: '选择环境 *',
                  border: OutlineInputBorder(),
                ),
                value: _selectedEnvId,
                items: allEnvs.map((env) {
                  return DropdownMenuItem(
                    value: env.id,
                    child: Text('${env.name} (${env.sshHost})'),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedEnvId = v),
                validator: (v) => v == null ? '请选择环境' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _branchController,
                decoration: const InputDecoration(
                  labelText: '部署分支',
                  hintText: '例如: master',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('部署模式'),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Push (本地构建)'),
                      value: 'push',
                      groupValue: _deployMode,
                      onChanged: (v) => setState(() => _deployMode = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Pull (服务端拉取)'),
                      value: 'pull',
                      groupValue: _deployMode,
                      onChanged: (v) => setState(() => _deployMode = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _deployPathController,
                decoration: const InputDecoration(
                  labelText: '部署路径 *',
                  hintText: '/var/www/project/dist',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty == true ? '请输入部署路径' : null,
              ),
              const SizedBox(height: 16),
              if (_deployMode == 'push') ...[
                TextFormField(
                  controller: _buildOutputPathController,
                  decoration: const InputDecoration(
                    labelText: '构建输出目录',
                    hintText: 'dist',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _buildCommandController,
                decoration: const InputDecoration(
                  labelText: '构建命令',
                  hintText: 'npm run build',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _preDeployController,
                decoration: const InputDecoration(
                  labelText: '部署前命令 (可选)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _postDeployController,
                decoration: const InputDecoration(
                  labelText: '部署后命令 (可选)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(_isSubmitting ? '提交中...' : '保存配置'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
