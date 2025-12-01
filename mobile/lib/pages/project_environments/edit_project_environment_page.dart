// mobile/lib/pages/project_environments/edit_project_environment_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import '../../models/environment.dart';
// import '../../providers/project_environment_provider.dart'; // Will need to create this

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
  bool _enabled = true; // Default

  ProjectEnvironment? _initialProjectEnvironment;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _branchController = TextEditingController();
    _deployPathController = TextEditingController();
    _buildCommandController = TextEditingController();
    _preDeployCommandController = TextEditingController();
    _postDeployCommandController = TextEditingController();
    _loadProjectEnvironment();
  }

  Future<void> _loadProjectEnvironment() async {
    // TODO: Fetch project environment details using a provider
    // For now, mock it or use an existing provider if found
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Placeholder for fetching data
      // Assume we get a ProjectEnvironment object
      _initialProjectEnvironment = ProjectEnvironment(
        id: widget.projectEnvironmentId,
        branch: 'main',
        deployPath: '/var/www/my-app',
        buildCommand: 'npm run build',
        preDeployCommand: 'echo "Pre-deploy script"',
        postDeployCommand: 'echo "Post-deploy script"',
        enabled: true,
        project: ProjectSimple(id: 1, name: 'My Project', projectKey: 'my-proj'),
        environment: EnvironmentSimple(id: 1, name: 'Staging', sshHost: 'staging.example.com'),
      );

      _branchController.text = _initialProjectEnvironment!.branch;
      _deployPathController.text = _initialProjectEnvironment!.deployPath;
      _buildCommandController.text = _initialProjectEnvironment!.buildCommand ?? '';
      _preDeployCommandController.text = _initialProjectEnvironment!.preDeployCommand ?? '';
      _postDeployCommandController.text = _initialProjectEnvironment!.postDeployCommand ?? '';
      _enabled = _initialProjectEnvironment!.enabled;
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      // TODO: Implement save logic using a provider
      // For now, just show a toast
      Fluttertoast.showToast(msg: '保存更改: ${_branchController.text}');
      context.pop();
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('编辑环境配置')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('编辑环境配置')),
        body: Center(child: Text('加载失败: $_error')),
      );
    }

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
              Text(
                '项目: ${_initialProjectEnvironment!.project!.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '环境: ${_initialProjectEnvironment!.environment!.name}',
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
                  onPressed: _saveChanges,
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
