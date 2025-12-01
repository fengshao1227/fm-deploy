class EnvironmentUrl {
  final int id;
  final String url;
  final int useCount;
  final DateTime? lastUsedAt;
  final DateTime createdAt;

  EnvironmentUrl({
    required this.id,
    required this.url,
    required this.useCount,
    this.lastUsedAt,
    required this.createdAt,
  });

  factory EnvironmentUrl.fromJson(Map<String, dynamic> json) {
    return EnvironmentUrl(
      id: json['id'] as int,
      url: json['url'] as String,
      useCount: json['usageCount'] as int? ?? 0,
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.tryParse(json['lastUsedAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(), // Fallback or make nullable
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'useCount': useCount,
      'lastUsedAt': lastUsedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
