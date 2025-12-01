// mobile/lib/pages/environments/add_environment_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import '../../providers/environment_provider.dart';

class AddEnvironmentPage extends ConsumerStatefulWidget {
  const AddEnvironmentPage({super.key});

  @override
  ConsumerState<AddEnvironmentPage> createState() => _AddEnvironmentPageState();
}

class _AddEnvironmentPageState extends ConsumerState<AddEnvironmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _userController = TextEditingController();
  final _keyPathController = TextEditingController();
  final _descController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _keyPathController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final response =
          await ref.read(environmentListProvider.notifier).createEnvironment(
                name: _nameController.text.trim(),
                sshHost: _hostController.text.trim(),
                sshPort: int.tryParse(_portController.text.trim()) ?? 22,
                sshUser: _userController.text.trim(),
                sshKeyPath: _keyPathController.text.trim().isEmpty
                    ? null
                    : _keyPathController.text.trim(),
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
        title: const Text('添加环境'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '环境名称 *',
                  hintText: '例如: 测试环境',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty == true ? '请输入环境名称' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _hostController,
                      decoration: const InputDecoration(
                        labelText: 'SSH 主机 *',
                        hintText: 'IP 或域名',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.isEmpty == true ? '请输入主机' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _portController,
                      decoration: const InputDecoration(
                        labelText: '端口 *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v?.isEmpty == true ? '必填' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _userController,
                decoration: const InputDecoration(
                  labelText: 'SSH 用户 *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty == true ? '请输入用户名' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _keyPathController,
                decoration: const InputDecoration(
                  labelText: 'SSH 密钥路径 (可选)',
                  hintText: '/root/.ssh/id_rsa',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: '描述 (可选)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
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
