import 'dart:io';

/// API 配置
class ApiConfig {
  // 开发环境 - Web/桌面
  static const String devBaseUrl = 'http://localhost:3000';

  // 开发环境 - Android 模拟器（模拟器中 10.0.2.2 指向宿主机的 localhost）
  static const String devAndroidEmulatorUrl = 'http://10.0.2.2:3000';

  // 生产环境
  static const String prodBaseUrl = 'http://117.72.163.3:3000';

  // 当前使用的地址（可根据环境切换）
  static const bool isProduction = false;

  static String get baseUrl {
    if (isProduction) return prodBaseUrl;
    // Android 模拟器需要使用特殊地址
    try {
      if (Platform.isAndroid) {
        return devAndroidEmulatorUrl;
      }
    } catch (_) {}
    return devBaseUrl;
  }

  // WebSocket 地址
  static String get wsUrl {
    final baseUri = Uri.parse(baseUrl);
    final wsScheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    return '$wsScheme://${baseUri.host}:${baseUri.port}/ws';
  }

  // API 路径 - 认证
  static const String authLogin = '/api/auth/login';
  static const String authMe = '/api/auth/me';
  static const String authChangePassword = '/api/auth/change-password';

  // API 路径 - 项目
  static const String projects = '/api/projects';
  static const String projectsAll = '/api/projects/all';

  // API 路径 - 环境
  static const String environments = '/api/environments';
  static const String environmentsAll = '/api/environments/all';

  // API 路径 - 项目环境配置
  static const String projectEnvironments = '/api/project-environments';

  // API 路径 - 快照
  static const String snapshots = '/api/snapshots';

  // API 路径 - 部署
  static const String deployments = '/api/deployments';

  // 超时配置
  static const int connectTimeout = 10000; // 10秒
  static const int receiveTimeout = 10000; // 10秒
}
