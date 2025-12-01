# FM Deploy 后端API交接文档

> 本文档供移动端开发使用，包含所有已完成的后端API接口。

## 基础配置

```
Base URL: http://localhost:3000/api
WebSocket: ws://localhost:3000/ws?token=<jwt_token>
认证方式: Bearer Token (JWT)
Token有效期: 7天
```

## 测试账号

| 角色 | 用户名 | 密码 |
|------|--------|------|
| 管理员 | admin | admin123 |
| 开发者 | developer | dev123 |

## 响应格式

```json
// 成功
{ "success": true, "data": {...}, "message": "可选提示" }

// 失败
{ "success": false, "error": "错误信息" }

// 分页
{ "success": true, "data": { "list": [...], "pagination": { "page": 1, "pageSize": 10, "total": 100, "totalPages": 10 } } }
```

---

## 1. 认证模块

### POST /auth/login - 登录
```json
// Request
{ "username": "admin", "password": "admin123" }

// Response
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": { "id": 1, "username": "admin", "name": "系统管理员", "role": "admin" }
  }
}
```

### GET /auth/me - 获取当前用户
```json
// Headers: Authorization: Bearer <token>
// Response
{
  "success": true,
  "data": { "id": 1, "username": "admin", "name": "系统管理员", "role": "admin", "createdAt": "2025-11-28T07:29:31.837Z" }
}
```

### POST /auth/change-password - 修改密码
```json
// Request
{ "oldPassword": "admin123", "newPassword": "newpassword" }

// Response
{ "success": true, "message": "密码修改成功" }
```

---

## 2. 项目管理

### GET /projects - 项目列表（分页）
```
Query: ?page=1&pageSize=10&type=frontend&keyword=FM
```
```json
{
  "success": true,
  "data": {
    "list": [{
      "id": 1,
      "name": "FM前端项目",
      "projectKey": "fm-frontend",
      "type": "frontend",
      "gitRepo": "https://github.com/example/fm.git",
      "description": "项目描述",
      "createdAt": "2025-11-28T07:35:14.283Z"
    }],
    "pagination": { "page": 1, "pageSize": 10, "total": 1, "totalPages": 1 }
  }
}
```

### GET /projects/all - 所有项目（下拉选择用）
```json
{
  "success": true,
  "data": [
    { "id": 1, "name": "FM前端项目", "projectKey": "fm-frontend", "type": "frontend" }
  ]
}
```

### GET /projects/:id - 项目详情
```json
{
  "success": true,
  "data": {
    "id": 1, "name": "FM前端项目", "projectKey": "fm-frontend", "type": "frontend",
    "gitRepo": "https://github.com/example/fm.git", "description": "描述",
    "projectEnvironments": [{
      "id": 1, "deployPath": "/var/www/fm", "branch": "master", "buildCommand": "npm run build",
      "environment": { "id": 1, "name": "生产环境", "sshHost": "192.168.1.100" }
    }]
  }
}
```

### POST /projects - 创建项目 (仅admin)
```json
// Request
{ "name": "项目名", "projectKey": "project-key", "type": "frontend", "gitRepo": "可选", "description": "可选" }
```

### PUT /projects/:id - 更新项目 (仅admin)
```json
// Request (所有字段可选)
{ "name": "新名称", "gitRepo": "新仓库", "description": "新描述" }
```

### DELETE /projects/:id - 删除项目 (仅admin)

---

## 3. 环境管理

### GET /environments - 环境列表（分页）
```
Query: ?page=1&pageSize=10&keyword=生产
```
```json
{
  "success": true,
  "data": {
    "list": [{
      "id": 1, "name": "生产环境", "sshHost": "192.168.1.100", "sshPort": 22,
      "sshUser": "root", "description": "正式服务器", "createdAt": "..."
    }],
    "pagination": {...}
  }
}
```

### GET /environments/all - 所有环境（下拉选择用）
```json
{
  "success": true,
  "data": [
    { "id": 1, "name": "生产环境", "sshHost": "192.168.1.100" }
  ]
}
```

### GET /environments/:id - 环境详情
```json
{
  "success": true,
  "data": {
    "id": 1, "name": "生产环境", "sshHost": "192.168.1.100", "sshPort": 22,
    "sshUser": "root", "sshKeyPath": "/root/.ssh/id_rsa", "description": "描述",
    "projectEnvironments": [{
      "id": 1, "deployPath": "/var/www/fm", "branch": "master",
      "project": { "id": 1, "name": "FM前端" }
    }]
  }
}
```

### POST /environments - 创建环境 (仅admin)
```json
// Request
{ "name": "环境名", "sshHost": "192.168.1.100", "sshPort": 22, "sshUser": "root", "sshKeyPath": "/root/.ssh/id_rsa", "description": "可选" }
```

### PUT /environments/:id - 更新环境 (仅admin)
### DELETE /environments/:id - 删除环境 (仅admin)

### POST /environments/:id/test - 测试SSH连接
```json
// Response
{ "success": true, "data": { "connected": true, "message": "SSH连接成功" } }
// 或
{ "success": true, "data": { "connected": false, "message": "SSH连接失败: Connection refused" } }
```

---

## 4. 项目环境配置

### GET /projects/:projectId/environments - 项目的环境配置列表
```json
{
  "success": true,
  "data": [{
    "id": 1, "deployPath": "/var/www/fm", "branch": "master",
    "buildCommand": "npm run build", "preDeployCommand": null, "postDeployCommand": "pm2 restart app",
    "enabled": true, "createdAt": "...",
    "environment": { "id": 1, "name": "生产环境", "sshHost": "192.168.1.100" }
  }]
}
```

### GET /project-environments/:id - 配置详情
```json
{
  "success": true,
  "data": {
    "id": 1, "deployPath": "/var/www/fm", "branch": "master",
    "buildCommand": "npm run build", "preDeployCommand": null, "postDeployCommand": "pm2 restart app",
    "enabled": true,
    "project": { "id": 1, "name": "FM前端", "projectKey": "fm-frontend", "type": "frontend" },
    "environment": { "id": 1, "name": "生产环境", "sshHost": "192.168.1.100", "sshPort": 22, "sshUser": "root" }
  }
}
```

### POST /projects/:projectId/environments - 添加配置 (仅admin)
```json
// Request
{
  "environmentId": 1,
  "deployPath": "/var/www/fm",
  "branch": "master",
  "buildCommand": "npm run build",      // 可选
  "preDeployCommand": "npm install",    // 可选
  "postDeployCommand": "pm2 restart"    // 可选
}
```

### PUT /project-environments/:id - 更新配置 (仅admin)
### DELETE /project-environments/:id - 删除配置 (仅admin)

### POST /project-environments/:id/toggle - 启用/禁用配置 (仅admin)
```json
// Response
{ "success": true, "data": { "id": 1, "enabled": false }, "message": "配置已禁用" }
```

---

## 5. 部署管理

### GET /deployments - 部署记录列表（分页）
```
Query: ?page=1&pageSize=10&projectEnvironmentId=1&status=success
status可选值: pending, running, success, failed
```
```json
{
  "success": true,
  "data": {
    "list": [{
      "id": 1, "status": "success",
      "commitHash": "abc1234", "commitMessage": "feat: add feature",
      "startedAt": "2025-11-28T10:00:00.000Z", "finishedAt": "2025-11-28T10:02:30.000Z",
      "createdAt": "2025-11-28T10:00:00.000Z",
      "project": { "id": 1, "name": "FM前端", "projectKey": "fm-frontend" },
      "environment": { "id": 1, "name": "生产环境" },
      "user": { "id": 1, "username": "admin", "name": "系统管理员" }
    }],
    "pagination": {...}
  }
}
```

### GET /projects/:projectId/deployments - 项目的部署记录
```
Query: ?page=1&pageSize=10
```

### GET /deployments/:id - 部署详情
```json
{
  "success": true,
  "data": {
    "id": 1, "status": "success",
    "commitHash": "abc1234567890", "commitMessage": "feat: add feature",
    "startedAt": "...", "finishedAt": "...", "errorMessage": null,
    "projectEnvironment": {
      "id": 1, "deployPath": "/var/www/fm", "branch": "master",
      "project": { "id": 1, "name": "FM前端", "projectKey": "fm-frontend", "type": "frontend" },
      "environment": { "id": 1, "name": "生产环境", "sshHost": "192.168.1.100" }
    },
    "user": { "id": 1, "username": "admin", "name": "系统管理员" }
  }
}
```

### POST /deployments - 创建部署任务
```json
// Request
{ "projectEnvironmentId": 1 }

// Response
{
  "success": true,
  "data": {
    "id": 10, "status": "pending",
    "project": { "id": 1, "name": "FM前端" },
    "environment": { "id": 1, "name": "生产环境" }
  },
  "message": "部署任务已创建"
}

// 错误
{ "success": false, "error": "该项目环境配置已禁用" }
{ "success": false, "error": "该项目环境已有部署任务正在执行" }
```

### GET /deployments/:id/logs - 获取部署日志
```json
{
  "success": true,
  "data": {
    "deploymentId": 1,
    "status": "running",
    "logs": [
      { "id": 1, "logType": "info", "message": "正在连接服务器...", "timestamp": "..." },
      { "id": 2, "logType": "info", "message": "已连接到服务器", "timestamp": "..." },
      { "id": 3, "logType": "stdout", "message": "Already up to date.", "timestamp": "..." },
      { "id": 4, "logType": "info", "message": "部署成功!", "timestamp": "..." }
    ]
  }
}
```
**logType**: info, stdout, stderr, error

### POST /deployments/:id/rollback - 回滚部署
```json
// Response
{ "success": true, "data": { "id": 11, "status": "pending", "originalDeploymentId": 1 }, "message": "回滚任务已创建" }

// 错误
{ "success": false, "error": "只能回滚成功的部署" }
```

### POST /deployments/:id/cancel - 取消部署
```json
// Response
{ "success": true, "message": "部署已取消" }

// 错误
{ "success": false, "error": "只能取消待执行或执行中的部署" }
```

---

## 6. WebSocket 实时通信

### 连接
```
ws://localhost:3000/ws?token=<jwt_token>
```

### 连接成功响应
```json
{ "type": "connected", "payload": { "message": "连接成功", "userId": 1, "username": "admin" } }
```

### 客户端发送

**订阅部署日志**
```json
{ "type": "subscribe_deployment", "payload": { "deploymentId": 1 } }
```

**取消订阅**
```json
{ "type": "unsubscribe_deployment", "payload": { "deploymentId": 1 } }
```

**心跳**
```json
{ "type": "ping", "payload": {} }
```

### 服务端推送

**订阅确认**
```json
{ "type": "subscribed", "payload": { "deploymentId": 1 } }
```

**实时日志**
```json
{
  "type": "deployment_log",
  "payload": {
    "deploymentId": 1,
    "step": "git",
    "logType": "info",
    "message": "拉取代码: master",
    "timestamp": "2025-11-28T10:00:05.000Z"
  }
}
```

**step 说明**
| step | 说明 |
|------|------|
| connect | SSH连接 |
| check | 检查目录 |
| pre_deploy | 部署前命令 |
| git | Git操作 |
| build | 构建 |
| post_deploy | 部署后命令 |
| complete | 完成 |
| error | 错误 |
| rollback | 回滚 |

**心跳响应**
```json
{ "type": "pong", "payload": {} }
```

---

## Flutter 代码示例

### HTTP 拦截器
```dart
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = StorageService.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // 跳转登录页
      NavigatorService.toLogin();
    }
    handler.next(err);
  }
}
```

### WebSocket 服务
```dart
class WebSocketService {
  WebSocketChannel? _channel;
  final _logController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get logStream => _logController.stream;

  void connect(String token) {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:3000/ws?token=$token'),
    );

    _channel?.stream.listen((message) {
      final data = jsonDecode(message);
      if (data['type'] == 'deployment_log') {
        _logController.add(data['payload']);
      }
    });
  }

  void subscribeDeployment(int deploymentId) {
    _channel?.sink.add(jsonEncode({
      'type': 'subscribe_deployment',
      'payload': {'deploymentId': deploymentId}
    }));
  }

  void unsubscribeDeployment(int deploymentId) {
    _channel?.sink.add(jsonEncode({
      'type': 'unsubscribe_deployment',
      'payload': {'deploymentId': deploymentId}
    }));
  }

  void disconnect() {
    _channel?.sink.close();
  }
}
```

---

## 权限说明

| 操作 | admin | developer |
|------|-------|-----------|
| 查看项目/环境/部署 | ✅ | ✅ |
| 创建/编辑/删除项目 | ✅ | ❌ |
| 创建/编辑/删除环境 | ✅ | ❌ |
| 创建/编辑/删除配置 | ✅ | ❌ |
| 执行部署 | ✅ | ✅ |
| 回滚/取消部署 | ✅ | ✅ |

---

## HTTP 状态码

| 状态码 | 说明 |
|--------|------|
| 200 | 成功 |
| 201 | 创建成功 |
| 400 | 请求参数错误 |
| 401 | 未认证/Token无效 |
| 403 | 权限不足 |
| 404 | 资源不存在 |
| 500 | 服务器错误 |

---

**后端代码位置**: `/Users/li/Desktop/work7_8/www/fm-deploy/backend`
**后端状态**: 所有核心功能已完成
