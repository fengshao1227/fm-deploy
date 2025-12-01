# FM Deploy 移动端 (Flutter)

移动端部署自动化系统 - Flutter 实现

## 运行项目

### 1. 在 Android Studio 中运行

1. 打开 Android Studio
2. 点击 `File` -> `Open`，选择 `/Users/li/Desktop/work7_8/www/fm-deploy/mobile` 目录
3. 等待 Gradle 同步完成
4. 如果提示安装 Flutter 插件，点击安装
5. 配置 Android cmdline-tools：
   - 打开 `Tools` -> `SDK Manager`
   - 选择 `SDK Tools` 标签
   - 勾选 `Android SDK Command-line Tools (latest)`
   - 点击 Apply 安装
6. 选择设备（模拟器或真机）
7. 点击 Run 按钮运行

### 2. 命令行运行

```bash
cd /Users/li/Desktop/work7_8/www/fm-deploy/mobile

# 检查环境
flutter doctor

# 获取依赖
flutter pub get

# 运行（Chrome）
flutter run -d chrome

# 运行（Android 模拟器）
flutter run -d emulator-5554

# 运行（真机）
flutter run -d <device-id>

# 查看可用设备
flutter devices
```

## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── config/
│   └── api_config.dart          # API 配置
├── models/
│   ├── api_response.dart        # 响应模型
│   ├── user.dart                # 用户模型
│   └── project.dart             # 项目模型
├── services/
│   ├── api_service.dart         # HTTP 请求封装
│   ├── auth_service.dart        # 认证服务
│   └── project_service.dart     # 项目服务
├── providers/
│   ├── auth_provider.dart       # 认证状态管理
│   └── project_provider.dart    # 项目状态管理
├── router/
│   └── app_router.dart          # 路由配置
├── pages/
│   ├── login/                   # 登录页
│   ├── home/                    # 首页
│   ├── projects/                # 项目列表和详情
│   └── settings/                # 设置页
├── widgets/
│   └── common/                  # 公共组件
└── utils/
    └── storage_util.dart        # 本地存储工具
```

## 已实现功能

- ✅ 登录/登出
- ✅ 自动登录（Token 持久化）
- ✅ 首页仪表盘
- ✅ 项目列表（分页、搜索、类型筛选）
- ✅ 项目详情
- ✅ 环境管理
- ✅ 部署执行
- ✅ 实时日志（WebSocket）
- ✅ 部署记录
- ✅ 设置页
- ✅ 修改密码

## 待开发功能

- 🚧 更多部署统计图表
- 🚧 推送通知

## 技术栈

| 技术 | 版本 | 用途 |
|------|------|------|
| Flutter | 3.38.3 | UI 框架 |
| flutter_riverpod | 2.6.1 | 状态管理 |
| dio | 5.7.0 | HTTP 请求 |
| go_router | 14.6.2 | 路由管理 |
| shared_preferences | 2.3.3 | 本地存储 |
| pull_to_refresh | 2.0.0 | 下拉刷新 |
| fluttertoast | 8.2.8 | Toast 提示 |

## API 配置

修改 `lib/config/api_config.dart`：

```dart
class ApiConfig {
  // 开发环境
  static const String devBaseUrl = 'http://localhost:3000';

  // 生产环境
  static const String prodBaseUrl = 'http://117.72.163.3:3000';

  // 切换环境
  static const bool isProduction = false;
  static String get baseUrl => isProduction ? prodBaseUrl : devBaseUrl;
}
```

## 测试账号

- 管理员: `admin` / `admin123`
- 开发者: `developer` / `dev123`

## 注意事项

1. **Android 真机调试**：如果使用真机，API 地址不能用 `localhost`，需要使用电脑 IP 或部署后的服务器地址

2. **iOS 开发**：需要 Xcode 和 CocoaPods，运行 `pod install` 安装依赖

3. **API 服务**：确保后端服务已启动，否则登录会失败
