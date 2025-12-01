// mobile/lib/pages/projects/add_project_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import '../../providers/project_provider.dart';

class AddProjectPage extends ConsumerStatefulWidget {
  const AddProjectPage({super.key});

  @override
  ConsumerState<AddProjectPage> createState() => _AddProjectPageState();
}

class _AddProjectPageState extends ConsumerState<AddProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _keyController = TextEditingController();
  final _repoController = TextEditingController();
  final _descController = TextEditingController();
  String _type = 'frontend';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
    _repoController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final response = await ref.read(projectListProvider.notifier).createProject(
            name: _nameController.text.trim(),
            projectKey: _keyController.text.trim(),
            type: _type,
            gitRepo: _repoController.text.trim().isEmpty
                ? null
                : _repoController.text.trim(),
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
          );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (response.success) {
          Fluttertoast.showToast(msg: '创建成功');
          context.pop();
        } else {
          Fluttertoast.showToast(msg: response.error ?? '创建失败');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加项目'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '项目名称 *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty == true ? '请输入项目名称' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _keyController,
                decoration: const InputDecoration(
                  labelText: '项目标识 *',
                  hintText: '例如: frontend-app',
                  helperText: '只能包含字母、数字、下划线、中划线',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入项目标识';
                  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_-]*$').hasMatch(v)) {
                    return '格式不正确';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('项目类型 *'),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('前端项目'),
                      value: 'frontend',
                      groupValue: _type,
                      onChanged: (v) => setState(() => _type = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('后端项目'),
                      value: 'backend',
                      groupValue: _type,
                      onChanged: (v) => setState(() => _type = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _repoController,
                decoration: const InputDecoration(
                  labelText: 'Git 仓库地址',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: '项目描述',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(_isSubmitting ? '提交中...' : '创建项目'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
