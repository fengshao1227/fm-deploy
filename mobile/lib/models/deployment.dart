import 'environment.dart';

/// 部署状态枚举
enum DeploymentStatus {
  pending,
  running,
  success,
  failed;

  static DeploymentStatus fromString(String status) {
    switch (status) {
      case 'pending':
        return DeploymentStatus.pending;
      case 'running':
        return DeploymentStatus.running;
      case 'success':
        return DeploymentStatus.success;
      case 'failed':
        return DeploymentStatus.failed;
      default:
        return DeploymentStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case DeploymentStatus.pending:
        return '等待中';
      case DeploymentStatus.running:
        return '执行中';
      case DeploymentStatus.success:
        return '成功';
      case DeploymentStatus.failed:
        return '失败';
    }
  }

  bool get isRunning => this == DeploymentStatus.running;
  bool get isPending => this == DeploymentStatus.pending;
  bool get isSuccess => this == DeploymentStatus.success;
  bool get isFailed => this == DeploymentStatus.failed;
}

/// 部署记录模型
class Deployment {
  final int id;
  final DeploymentStatus status;
  final String? commitHash;
  final String? commitMessage;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? errorMessage;
  final DateTime? createdAt;
  final DeploymentProject? project;
  final DeploymentEnvironment? environment;
  final DeploymentUser? user;
  final ProjectEnvironment? projectEnvironment;

  Deployment({
    required this.id,
    required this.status,
    this.commitHash,
    this.commitMessage,
    this.startedAt,
    this.finishedAt,
    this.errorMessage,
    this.createdAt,
    this.project,
    this.environment,
    this.user,
    this.projectEnvironment,
  });

  factory Deployment.fromJson(Map<String, dynamic> json) {
    return Deployment(
      id: json['id'] as int,
      status: DeploymentStatus.fromString((json['status'] ?? 'pending').toString()),
      commitHash: json['commitHash']?.toString(),
      commitMessage: json['commitMessage']?.toString(),
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString())
          : null,
      finishedAt: json['finishedAt'] != null
          ? DateTime.tryParse(json['finishedAt'].toString())
          : null,
      errorMessage: json['errorMessage']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      project: json['project'] != null
          ? DeploymentProject.fromJson(json['project'] as Map<String, dynamic>)
          : null,
      environment: json['environment'] != null
          ? DeploymentEnvironment.fromJson(json['environment'] as Map<String, dynamic>)
          : null,
      user: json['user'] != null
          ? DeploymentUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      projectEnvironment: json['projectEnvironment'] != null
          ? ProjectEnvironment.fromJson(json['projectEnvironment'] as Map<String, dynamic>)
          : null,
    );
  }

  /// 获取短提交哈希
  String? get shortCommitHash {
    if (commitHash == null) return null;
    return commitHash!.length > 7 ? commitHash!.substring(0, 7) : commitHash;
  }

  /// 计算执行时长（秒）
  int? get durationSeconds {
    if (startedAt == null || finishedAt == null) return null;
    return finishedAt!.difference(startedAt!).inSeconds;
  }

  /// 格式化的执行时长
  String? get durationFormatted {
    final seconds = durationSeconds;
    if (seconds == null) return null;
    if (seconds < 60) return '$seconds秒';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes分$remainingSeconds秒';
  }
}

/// 部署中的项目信息
class DeploymentProject {
  final int id;
  final String name;
  final String projectKey;
  final String? type;

  DeploymentProject({
    required this.id,
    required this.name,
    required this.projectKey,
    this.type,
  });

  factory DeploymentProject.fromJson(Map<String, dynamic> json) {
    return DeploymentProject(
      id: json['id'] as int,
      name: (json['name'] ?? '').toString(),
      projectKey: (json['projectKey'] ?? '').toString(),
      type: json['type']?.toString(),
    );
  }
}

/// 部署中的环境信息
class DeploymentEnvironment {
  final int id;
  final String name;
  final String? sshHost;

  DeploymentEnvironment({
    required this.id,
    required this.name,
    this.sshHost,
  });

  factory DeploymentEnvironment.fromJson(Map<String, dynamic> json) {
    return DeploymentEnvironment(
      id: json['id'] as int,
      name: (json['name'] ?? '').toString(),
      sshHost: json['sshHost']?.toString(),
    );
  }
}

/// 部署操作人
class DeploymentUser {
  final int id;
  final String username;
  final String name;

  DeploymentUser({
    required this.id,
    required this.username,
    required this.name,
  });

  factory DeploymentUser.fromJson(Map<String, dynamic> json) {
    final username = (json['username'] ?? '').toString();
    return DeploymentUser(
      id: json['id'] as int,
      username: username,
      name: json['name']?.toString() ?? username,
    );
  }
}

/// 部署日志
class DeploymentLog {
  final int id;
  final String logType;
  final String message;
  final DateTime timestamp;

  DeploymentLog({
    required this.id,
    required this.logType,
    required this.message,
    required this.timestamp,
  });

  factory DeploymentLog.fromJson(Map<String, dynamic> json) {
    return DeploymentLog(
      id: json['id'] as int,
      logType: (json['logType'] ?? 'info').toString(),
      message: (json['message'] ?? '').toString(),
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  bool get isError => logType == 'error' || logType == 'stderr';
  bool get isInfo => logType == 'info';
  bool get isStdout => logType == 'stdout';
}

/// 实时日志消息
class RealtimeLog {
  final int deploymentId;
  final String step;
  final String logType;
  final String message;
  final DateTime timestamp;

  RealtimeLog({
    required this.deploymentId,
    required this.step,
    required this.logType,
    required this.message,
    required this.timestamp,
  });

  factory RealtimeLog.fromJson(Map<String, dynamic> json) {
    return RealtimeLog(
      deploymentId: json['deploymentId'] as int,
      step: (json['step'] ?? '').toString(),
      logType: (json['logType'] ?? 'info').toString(),
      message: (json['message'] ?? '').toString(),
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  bool get isError => logType == 'error' || logType == 'stderr';

  String get stepLabel {
    switch (step) {
      case 'connect':
        return 'SSH连接';
      case 'check':
        return '检查目录';
      case 'pre_deploy':
        return '部署前';
      case 'git':
        return 'Git操作';
      case 'build':
        return '构建';
      case 'post_deploy':
        return '部署后';
      case 'complete':
        return '完成';
      case 'error':
        return '错误';
      case 'rollback':
        return '回滚';
      default:
        return step;
    }
  }
}
