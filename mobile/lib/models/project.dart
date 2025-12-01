/// 项目模型
class Project {
  final int id;
  final String name;
  final String projectKey;
  final String type;
  final String? gitRepo;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ProjectEnvironment>? projectEnvironments;

  Project({
    required this.id,
    required this.name,
    required this.projectKey,
    required this.type,
    this.gitRepo,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.projectEnvironments,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      projectKey: json['projectKey'] ?? '',
      type: json['type'] ?? 'frontend',
      gitRepo: json['gitRepo'],
      description: json['description'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
      projectEnvironments: json['projectEnvironments'] != null
          ? (json['projectEnvironments'] as List)
              .map((e) => ProjectEnvironment.fromJson(e))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'projectKey': projectKey,
      'type': type,
      'gitRepo': gitRepo,
      'description': description,
    };
  }

  bool get isFrontend => type == 'frontend';
  bool get isBackend => type == 'backend';

  String get typeLabel => isFrontend ? '前端' : '后端';

  Project copyWith({
    String? name,
    String? gitRepo,
    String? description,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      projectKey: projectKey,
      type: type,
      gitRepo: gitRepo ?? this.gitRepo,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt,
      projectEnvironments: projectEnvironments,
    );
  }
}

/// 项目环境配置
class ProjectEnvironment {
  final int id;
  final String deployPath;
  final String branch;
  final String? buildCommand;
  final Environment? environment;

  ProjectEnvironment({
    required this.id,
    required this.deployPath,
    required this.branch,
    this.buildCommand,
    this.environment,
  });

  factory ProjectEnvironment.fromJson(Map<String, dynamic> json) {
    return ProjectEnvironment(
      id: json['id'] ?? 0,
      deployPath: json['deployPath'] ?? '',
      branch: json['branch'] ?? 'master',
      buildCommand: json['buildCommand'],
      environment: json['environment'] != null
          ? Environment.fromJson(json['environment'])
          : null,
    );
  }
}

/// 服务器环境
class Environment {
  final int id;
  final String name;
  final String? sshHost;

  Environment({
    required this.id,
    required this.name,
    this.sshHost,
  });

  factory Environment.fromJson(Map<String, dynamic> json) {
    return Environment(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      sshHost: json['sshHost'],
    );
  }
}

/// 简单项目（用于下拉选择）
class SimpleProject {
  final int id;
  final String name;
  final String projectKey;
  final String type;

  SimpleProject({
    required this.id,
    required this.name,
    required this.projectKey,
    required this.type,
  });

  factory SimpleProject.fromJson(Map<String, dynamic> json) {
    return SimpleProject(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      projectKey: json['projectKey'] ?? '',
      type: json['type'] ?? 'frontend',
    );
  }
}
