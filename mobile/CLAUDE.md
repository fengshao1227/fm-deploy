[根目录](../CLAUDE.md) > **mobile**

# Mobile - Flutter 移动端应用

> AI 上下文文档 | 最后更新: 2025-12-01T10:20:34+08:00

## 模块职责

移动端应用提供跨平台 (iOS/Android/Web) 的部署管理界面，支持项目浏览、一键部署、实时日志查看、版本回滚等功能。

## 技术栈

- **框架**: Flutter >= 3.10.1
- **语言**: Dart
- **状态管理**: Riverpod (flutter_riverpod)
- **路由**: go_router
- **网络请求**: Dio
- **本地存储**: shared_preferences
- **实时通信**: web_socket_channel

## 入口与启动

**入口文件**: `lib/main.dart`

```bash
# 获取依赖
flutter pub get

# 运行开发模式
flutter run

# 指定设备运行
flutter run -d iphone
flutter run -d android
flutter run -d chrome  # Web

# 构建发布版本
flutter build apk
flutter build ios
flutter build web
```

## 目录结构

```
mobile/
├── lib/
│   ├── main.dart                 # 应用入口
│   ├── config/
│   │   └── api_config.dart       # API 配置
│   ├── router/
│   │   └── app_router.dart       # 路由配置 (go_router)
│   ├── models/                   # 数据模型
│   │   ├── user.dart
│   │   ├── project.dart
│   │   ├── environment.dart
│   │   ├── deployment.dart
│   │   └── api_response.dart
│   ├── services/                 # 服务层
│   │   ├── api_service.dart      # HTTP 请求封装
│   │   ├── auth_service.dart     # 认证服务
│   │   ├── project_service.dart  # 项目服务
│   │   ├── environment_service.dart
│   │   ├── deployment_service.dart
│   │   └── websocket_service.dart
│   ├── providers/                # 状态管理 (Riverpod)
│   │   ├── auth_provider.dart
│   │   ├── project_provider.dart
│   │   ├── environment_provider.dart
│   │   └── deployment_provider.dart
│   ├── pages/                    # 页面
│   │   ├── login/
│   │   │   └── login_page.dart
│   │   ├── home/
│   │   │   └── home_page.dart
│   │   ├── projects/
│   │   │   ├── projects_page.dart
│   │   │   └── project_detail_page.dart
│   │   ├── environments/
│   │   │   ├── environments_page.dart
│   │   │   └── environment_detail_page.dart
│   │   ├── deployments/
│   │   │   ├── deployments_page.dart
│   │   │   ├── deployment_detail_page.dart
│   │   │   └── deploy_page.dart
│   │   └── settings/
│   │       ├── settings_page.dart
│   │       └── change_password_page.dart
│   ├── widgets/                  # 可复用组件
│   │   └── common/
│   │       ├── main_scaffold.dart
│   │       └── loading_button.dart
│   └── utils/
│       └── storage_util.dart     # 本地存储工具
├── pubspec.yaml
├── android/                      # Android 平台配置
├── ios/                          # iOS 平台配置
├── web/                          # Web 平台配置
├── macos/                        # macOS 平台配置
├── linux/                        # Linux 平台配置
└── windows/                      # Windows 平台配置
```

## 对外接口

### 页面路由

| 路由 | 页面 | 说明 |
|------|------|------|
| `/login` | LoginPage | 登录页 |
| `/` | HomePage | 首页 |
| `/projects` | ProjectsPage | 项目列表 |
| `/projects/:id` | ProjectDetailPage | 项目详情 |
| `/environments` | EnvironmentsPage | 环境列表 |
| `/environments/:id` | EnvironmentDetailPage | 环境详情 |
| `/deployments` | DeploymentsPage | 部署记录列表 |
| `/deployments/:id` | DeploymentDetailPage | 部署详情/日志 |
| `/deploy` | DeployPage | 执行部署 |
| `/settings` | SettingsPage | 设置页 |
| `/settings/change-password` | ChangePasswordPage | 修改密码 |

### 导航结构

- **底部导航栏** (MainScaffold):
  - 首页 (HomePage)
  - 项目 (ProjectsPage)
  - 部署 (DeploymentsPage)
  - 设置 (SettingsPage)

## 关键依赖与配置

### 主要依赖 (pubspec.yaml)

| 依赖 | 版本 | 用途 |
|------|------|------|
| flutter_riverpod | ^2.6.1 | 状态管理 |
| dio | ^5.7.0 | 网络请求 |
| go_router | ^14.6.2 | 路由管理 |
| shared_preferences | ^2.3.3 | 本地存储 |
| web_socket_channel | ^3.0.1 | WebSocket |
| pull_to_refresh | ^2.0.0 | 下拉刷新 |
| fluttertoast | ^8.2.8 | Toast 提示 |

### API 配置

配置文件: `lib/config/api_config.dart`

```dart
class ApiConfig {
  static const String baseUrl = 'http://your-api-host:3000/api';
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;
}
```

## 数据模型

### User (用户)

```dart
class User {
  final int id;
  final String username;
  final String name;
  final String role;
}
```

### Project (项目)

```dart
class Project {
  final int id;
  final String name;
  final String projectKey;
  final String type;
  final String? gitRepo;
  final String? description;
}
```

### Environment (环境)

```dart
class Environment {
  final int id;
  final String name;
  final String sshHost;
  final int sshPort;
  final String sshUser;
}
```

### Deployment (部署)

```dart
class Deployment {
  final int id;
  final int projectEnvironmentId;
  final String status;
  final String? commitHash;
  final String? commitMessage;
  final DateTime? startedAt;
  final DateTime? finishedAt;
}
```

## 状态管理 (Riverpod)

### Provider 结构

```dart
// 认证状态
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>

// 项目列表
final projectProvider = StateNotifierProvider<ProjectNotifier, ProjectState>

// 环境列表
final environmentProvider = StateNotifierProvider<EnvironmentNotifier, EnvironmentState>

// 部署状态
final deploymentProvider = StateNotifierProvider<DeploymentNotifier, DeploymentState>
```

### 使用方式

```dart
// 读取状态
final authState = ref.watch(authProvider);

// 调用方法
ref.read(authProvider.notifier).login(username, password);
```

## 测试与质量

```bash
# 运行测试
flutter test

# 代码分析
flutter analyze

# 格式化代码
dart format lib/
```

## 常见问题 (FAQ)

### 1. API 连接失败
- 检查 `api_config.dart` 中的 baseUrl 配置
- 确认后端服务已启动
- iOS 真机需要配置 App Transport Security

### 2. 登录后跳转问题
- 检查 Token 是否正确保存
- 确认 `StorageUtil.isLoggedIn()` 返回值

### 3. WebSocket 连接
- 确保后端 WebSocket 服务已启动
- 检查网络连接状态

### 4. 热重载不生效
- 尝试重新运行 `flutter run`
- 清除缓存 `flutter clean && flutter pub get`

## 相关文件清单

- `lib/main.dart` - 应用入口
- `lib/router/app_router.dart` - 路由配置
- `lib/services/api_service.dart` - API 封装
- `lib/providers/auth_provider.dart` - 认证状态
- `lib/config/api_config.dart` - API 配置
- `pubspec.yaml` - 依赖配置

## 变更记录 (Changelog)

### 2025-12-01
- 初始化模块 AI 上下文文档
