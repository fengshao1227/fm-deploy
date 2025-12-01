import 'dart:convert';

/// 用户模型
class User {
  final int id;
  final String username;
  final String name;
  final String role;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'developer',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'role': role,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory User.fromJsonString(String jsonStr) {
    return User.fromJson(jsonDecode(jsonStr));
  }

  bool get isAdmin => role == 'admin';
}

/// 登录响应数据
class LoginData {
  final String token;
  final User user;

  LoginData({
    required this.token,
    required this.user,
  });

  factory LoginData.fromJson(Map<String, dynamic> json) {
    return LoginData(
      token: json['token'] ?? '',
      user: User.fromJson(json['user'] ?? {}),
    );
  }
}
