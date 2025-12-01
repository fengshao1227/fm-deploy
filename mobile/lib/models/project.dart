import 'environment.dart'; // Import ProjectEnvironment and Environment from here

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
