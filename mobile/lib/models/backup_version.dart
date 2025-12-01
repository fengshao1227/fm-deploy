// lib/models/backup_version.dart

class BackupVersion {
  final int id;
  final String name;
  final String path;
  final DateTime createdAt;
  final int deploymentId;

  BackupVersion({
    required this.id,
    required this.name,
    required this.path,
    required this.createdAt,
    required this.deploymentId,
  });

  factory BackupVersion.fromJson(Map<String, dynamic> json) {
    return BackupVersion(
      id: json['id'],
      name: json['name'],
      path: json['path'],
      createdAt: DateTime.parse(json['createdAt']),
      deploymentId: json['deploymentId'],
    );
  }

  /// 格式化显示时间
  String get formattedTime {
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} '
           '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }
}