/// 环境模型
class Environment {
  final int id;
  final String name;
  final String sshHost;
  final int sshPort;
  final String sshUser;
  final String? sshKeyPath;
  final String? description;
  final DateTime? createdAt;
  final List<ProjectEnvironment>? projectEnvironments;

  Environment({
    required this.id,
    required this.name,
    required this.sshHost,
    required this.sshPort,
    required this.sshUser,
    this.sshKeyPath,
    this.description,
    this.createdAt,
    this.projectEnvironments,
  });

  factory Environment.fromJson(Map<String, dynamic> json) {
    return Environment(
      id: json['id'] as int,
      name: (json['name'] ?? '').toString(),
      sshHost: (json['sshHost'] ?? '').toString(),
      sshPort: json['sshPort'] as int? ?? 22,
      sshUser: (json['sshUser'] ?? '').toString(),
      sshKeyPath: json['sshKeyPath']?.toString(),
      description: json['description']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      projectEnvironments: json['projectEnvironments'] != null
          ? (json['projectEnvironments'] as List)
              .map((e) => ProjectEnvironment.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sshHost': sshHost,
      'sshPort': sshPort,
      'sshUser': sshUser,
      'sshKeyPath': sshKeyPath,
      'description': description,
    };
  }
}

/// 环境简要信息（用于下拉选择）
class EnvironmentSimple {
  final int id;
  final String name;
  final String? sshHost;

  EnvironmentSimple({
    required this.id,
    required this.name,
    this.sshHost,
  });

  factory EnvironmentSimple.fromJson(Map<String, dynamic> json) {
    return EnvironmentSimple(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? 'Unknown',
      sshHost: json['sshHost']?.toString(),
    );
  }
}

/// 项目环境配置
class ProjectEnvironment {
  final int id;
  final String deployPath;
  final String branch;
  final String? deployMode;
  final String? buildOutputPath;
  final String? buildCommand;
  final String? preDeployCommand;
  final String? postDeployCommand;
  final bool enabled;
  final DateTime? createdAt;
  final ProjectSimple? project;
  final EnvironmentSimple? environment;

  ProjectEnvironment({
    required this.id,
    required this.deployPath,
    required this.branch,
    this.deployMode,
    this.buildOutputPath,
    this.buildCommand,
    this.preDeployCommand,
    this.postDeployCommand,
    this.enabled = true,
    this.createdAt,
    this.project,
    this.environment,
  });

  factory ProjectEnvironment.fromJson(Map<String, dynamic> json) {
    return ProjectEnvironment(
      id: json['id'] as int? ?? 0,
      deployPath: json['deployPath']?.toString() ?? '',
      branch: json['branch']?.toString() ?? '',
      deployMode: json['deployMode']?.toString(),
      buildOutputPath: json['buildOutputPath']?.toString(),
      buildCommand: json['buildCommand']?.toString(),
      preDeployCommand: json['preDeployCommand']?.toString(),
      postDeployCommand: json['postDeployCommand']?.toString(),
      enabled: json['enabled'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      project: json['project'] != null
          ? ProjectSimple.fromJson(json['project'] as Map<String, dynamic>)
          : null,
      environment: json['environment'] != null
          ? EnvironmentSimple.fromJson(json['environment'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deployPath': deployPath,
      'branch': branch,
      'deployMode': deployMode,
      'buildOutputPath': buildOutputPath,
      'buildCommand': buildCommand,
      'preDeployCommand': preDeployCommand,
      'postDeployCommand': postDeployCommand,
    };
  }
}

/// 项目简要信息
class ProjectSimple {
  final int id;
  final String name;
  final String projectKey;
  final String? type;

  ProjectSimple({
    required this.id,
    required this.name,
    required this.projectKey,
    this.type,
  });

  factory ProjectSimple.fromJson(Map<String, dynamic> json) {
    return ProjectSimple(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      projectKey: json['projectKey']?.toString() ?? '',
      type: json['type']?.toString(),
    );
  }

  bool get isFrontend => type == 'frontend';
}

/// SSH 连接测试结果
class SshTestResult {
  final bool connected;
  final String message;

  SshTestResult({
    required this.connected,
    required this.message,
  });

  factory SshTestResult.fromJson(Map<String, dynamic> json) {
    return SshTestResult(
      connected: json['connected'] as bool? ?? false,
      message: (json['message'] ?? '').toString(),
    );
  }
}
