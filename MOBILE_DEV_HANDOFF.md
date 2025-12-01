# FM Deploy 移动端开发交接文档

## 项目概述

FM Deploy 是一个移动端部署自动化系统，用于在手机上管理和执行前端及PHP后端项目的部署任务。

### 项目目标
- 通过手机APP实现一键部署
- 实时查看部署日志和状态
- 管理多个项目和多个环境（测试/生产）
- 支持部署回滚功能

---

## 技术栈建议

### 移动端
- **框架**: Flutter 3.x
- **状态管理**: Riverpod 或 GetX
- **HTTP客户端**: Dio
- **WebSocket**: web_socket_channel
- **本地存储**: shared_preferences / hive
- **UI组件**: Material Design 3

### 后端（已完成）
- Node.js + Express + TypeScript
- TypeORM + MySQL
- JWT认证
- WebSocket实时通信
- SSH2远程执行

---

## 后端API文档

### 基础信息
- **本地开发地址**: `http://localhost:3000`
- **生产地址**: `http://117.72.163.3:3000`（待部署）
- **认证方式**: Bearer Token (JWT)

### API响应格式

**成功响应**:
```json
{
  "success": true,
  "data": { ... },
  "message": "操作成功"  // 可选
}
```

**错误响应**:
```json
{
  "success": false,
  "error": "错误信息"
}
```

**分页响应**:
```json
{
  "success": true,
  "data": {
    "list": [...],
    "pagination": {
      "page": 1,
      "pageSize": 10,
      "total": 100,
      "totalPages": 10
    }
  }
}
```

---

## 已完成的API接口

### 1. 认证模块 (Auth)

#### 1.1 登录
```
POST /api/auth/login
Content-Type: application/json

Request:
{
  "username": "admin",
  "password": "admin123"
}

Response:
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 1,
      "username": "admin",
      "name": "系统管理员",
      "role": "admin"
    }
  }
}
```

#### 1.2 获取当前用户信息
```
GET /api/auth/me
Authorization: Bearer <token>

Response:
{
  "success": true,
  "data": {
    "id": 1,
    "username": "admin",
    "name": "系统管理员",
    "role": "admin",
    "createdAt": "2025-11-28T07:29:31.837Z"
  }
}
```

#### 1.3 修改密码
```
POST /api/auth/change-password
Authorization: Bearer <token>
Content-Type: application/json

Request:
{
  "oldPassword": "admin123",
  "newPassword": "newpassword"
}

Response:
{
  "success": true,
  "message": "密码修改成功"
}
```

### 2. 项目管理模块 (Projects)

#### 2.1 获取项目列表（分页）
```
GET /api/projects?page=1&pageSize=10&type=frontend&keyword=FM
Authorization: Bearer <token>

Query参数:
- page: 页码，默认1
- pageSize: 每页数量，默认10
- type: 项目类型过滤 (frontend/backend)
- keyword: 关键字搜索（项目名称/项目标识）

Response:
{
  "success": true,
  "data": {
    "list": [
      {
        "id": 1,
        "name": "FM前端项目",
        "projectKey": "fm-frontend",
        "type": "frontend",
        "gitRepo": "https://github.com/example/fm-frontend.git",
        "description": "FM系统Vue3前端项目",
        "createdAt": "2025-11-28T07:35:14.283Z",
        "updatedAt": "2025-11-28T07:35:33.000Z"
      }
    ],
    "pagination": {
      "page": 1,
      "pageSize": 10,
      "total": 1,
      "totalPages": 1
    }
  }
}
```

#### 2.2 获取所有项目（简单列表，用于下拉选择）
```
GET /api/projects/all
Authorization: Bearer <token>

Response:
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "FM前端项目",
      "projectKey": "fm-frontend",
      "type": "frontend"
    },
    {
      "id": 2,
      "name": "FM后端",
      "projectKey": "fm-backend",
      "type": "backend"
    }
  ]
}
```

#### 2.3 获取项目详情
```
GET /api/projects/:id
Authorization: Bearer <token>

Response:
{
  "success": true,
  "data": {
    "id": 1,
    "name": "FM前端项目",
    "projectKey": "fm-frontend",
    "type": "frontend",
    "gitRepo": "https://github.com/example/fm-frontend.git",
    "description": "FM系统Vue3前端项目",
    "createdAt": "2025-11-28T07:35:14.283Z",
    "updatedAt": "2025-11-28T07:35:33.000Z",
    "projectEnvironments": [
      {
        "id": 1,
        "deployPath": "/var/www/fm-frontend",
        "branch": "master",
        "buildCommand": "npm run build",
        "environment": {
          "id": 1,
          "name": "生产环境",
          "sshHost": "192.168.1.100"
        }
      }
    ]
  }
}
```

#### 2.4 创建项目（仅管理员）
```
POST /api/projects
Authorization: Bearer <token>
Content-Type: application/json

Request:
{
  "name": "FM前端",
  "projectKey": "fm-frontend",      // 必填，唯一标识
  "type": "frontend",               // 必填，frontend 或 backend
  "gitRepo": "https://github.com/example/fm.git",  // 选填
  "description": "项目描述"          // 选填
}

Response:
{
  "success": true,
  "data": { ... },
  "message": "项目创建成功"
}
```

#### 2.5 更新项目（仅管理员）
```
PUT /api/projects/:id
Authorization: Bearer <token>
Content-Type: application/json

Request:
{
  "name": "新项目名称",      // 选填
  "gitRepo": "新仓库地址",   // 选填
  "description": "新描述"    // 选填
}

Response:
{
  "success": true,
  "data": { ... },
  "message": "项目更新成功"
}
```

#### 2.6 删除项目（仅管理员）
```
DELETE /api/projects/:id
Authorization: Bearer <token>

Response:
{
  "success": true,
  "message": "项目删除成功"
}

错误情况:
{
  "success": false,
  "error": "该项目下存在环境配置，请先删除环境配置"
}
```

### 3. 环境管理模块 (Environments)

#### 3.1 获取环境列表（分页）
```
GET /api/environments?page=1&pageSize=10&keyword=生产
Authorization: Bearer <token>

Query参数:
- page: 页码，默认1
- pageSize: 每页数量，默认10
- keyword: 关键字搜索（环境名称）

Response:
{
  "success": true,
  "data": {
    "list": [
      {
        "id": 1,
        "name": "生产环境",
        "sshHost": "192.168.1.100",
        "sshPort": 22,
        "sshUser": "root",
        "description": "正式服务器",
        "createdAt": "2025-11-28T08:00:00.000Z",
        "updatedAt": "2025-11-28T08:00:00.000Z"
      }
    ],
    "pagination": {
      "page": 1,
      "pageSize": 10,
      "total": 1,
      "totalPages": 1
    }
  }
}
```

#### 3.2 获取所有环境（简单列表，用于下拉选择）
```
GET /api/environments/all
Authorization: Bearer <token>

Response:
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "生产环境",
      "sshHost": "192.168.1.100"
    },
    {
      "id": 2,
      "name": "测试环境",
      "sshHost": "192.168.1.101"
    }
  ]
}
```

#### 3.3 获取环境详情
```
GET /api/environments/:id
Authorization: Bearer <token>

Response:
{
  "success": true,
  "data": {
    "id": 1,
    "name": "生产环境",
    "sshHost": "192.168.1.100",
    "sshPort": 22,
    "sshUser": "root",
    "sshKeyPath": "/root/.ssh/id_rsa",
    "description": "正式服务器",
    "createdAt": "2025-11-28T08:00:00.000Z",
    "updatedAt": "2025-11-28T08:00:00.000Z",
    "projectEnvironments": [
      {
        "id": 1,
        "deployPath": "/var/www/fm-frontend",
        "branch": "master",
        "project": {
          "id": 1,
          "name": "FM前端项目"
        }
      }
    ]
  }
}
```

#### 3.4 创建环境（仅管理员）
```
POST /api/environments
Authorization: Bearer <token>
Content-Type: application/json

Request:
{
  "name": "生产环境",           // 必填
  "sshHost": "192.168.1.100",   // 必填
  "sshPort": 22,                // 选填，默认22
  "sshUser": "root",            // 必填
  "sshKeyPath": "/root/.ssh/id_rsa",  // 必填，SSH私钥路径
  "description": "正式服务器"   // 选填
}

Response:
{
  "success": true,
  "data": { ... },
  "message": "环境创建成功"
}
```

#### 3.5 更新环境（仅管理员）
```
PUT /api/environments/:id
Authorization: Bearer <token>
Content-Type: application/json

Request:
{
  "name": "新环境名称",         // 选填
  "sshHost": "192.168.1.200",   // 选填
  "sshPort": 22,                // 选填
  "sshUser": "deploy",          // 选填
  "sshKeyPath": "/home/deploy/.ssh/id_rsa",  // 选填
  "description": "新描述"       // 选填
}

Response:
{
  "success": true,
  "data": { ... },
  "message": "环境更新成功"
}
```

#### 3.6 删除环境（仅管理员）
```
DELETE /api/environments/:id
Authorization: Bearer <token>

Response:
{
  "success": true,
  "message": "环境删除成功"
}

错误情况:
{
  "success": false,
  "error": "该环境下存在项目配置，请先删除项目配置"
}
```

#### 3.7 测试SSH连接
```
POST /api/environments/:id/test
Authorization: Bearer <token>

Response (成功):
{
  "success": true,
  "data": {
    "connected": true,
    "message": "SSH连接成功"
  }
}

Response (失败):
{
  "success": true,
  "data": {
    "connected": false,
    "message": "SSH连接失败: Connection refused"
  }
}
```

---

### 4. 项目环境配置模块 (ProjectEnvironments)

#### 4.1 获取项目的环境配置列表
```
GET /api/projects/:projectId/environments
Authorization: Bearer <token>

Response:
{
  "success": true,
  "data": [
    {
      "id": 1,
      "deployPath": "/var/www/fm-frontend",
      "branch": "master",
      "buildCommand": "npm run build",
      "preDeployCommand": null,
      "postDeployCommand": "pm2 restart fm-frontend",
      "enabled": true,
      "createdAt": "2025-11-28T09:00:00.000Z",
      "environment": {
        "id": 1,
        "name": "生产环境",
        "sshHost": "192.168.1.100"
      }
    }
  ]
}
```

#### 4.2 获取项目环境配置详情
```
GET /api/project-environments/:id
Authorization: Bearer <token>

Response:
{
  "success": true,
  "data": {
    "id": 1,
    "deployPath": "/var/www/fm-frontend",
    "branch": "master",
    "buildCommand": "npm run build",
    "preDeployCommand": null,
    "postDeployCommand": "pm2 restart fm-frontend",
    "enabled": true,
    "createdAt": "2025-11-28T09:00:00.000Z",
    "updatedAt": "2025-11-28T09:00:00.000Z",
    "project": {
      "id": 1,
      "name": "FM前端项目",
      "projectKey": "fm-frontend",
      "type": "frontend"
    },
    "environment": {
      "id": 1,
      "name": "生产环境",
      "sshHost": "192.168.1.100",
      "sshPort": 22,
      "sshUser": "root"
    }
  }
}
```

#### 4.3 添加项目环境配置（仅管理员）
```
POST /api/projects/:projectId/environments
Authorization: Bearer <token>
Content-Type: application/json

Request:
{
  "environmentId": 1,                    // 必填，环境ID
  "deployPath": "/var/www/fm-frontend",  // 必填，部署目录
  "branch": "master",                    // 必填，Git分支
  "buildCommand": "npm run build",       // 选填，构建命令
  "preDeployCommand": "npm install",     // 选填，部署前命令
  "postDeployCommand": "pm2 restart app" // 选填，部署后命令
}

Response:
{
  "success": true,
  "data": { ... },
  "message": "项目环境配置创建成功"
}

错误情况:
{
  "success": false,
  "error": "该项目已存在此环境的配置"
}
```

#### 4.4 更新项目环境配置（仅管理员）
```
PUT /api/project-environments/:id
Authorization: Bearer <token>
Content-Type: application/json

Request:
{
  "deployPath": "/var/www/new-path",     // 选填
  "branch": "develop",                   // 选填
  "buildCommand": "npm run build:prod",  // 选填
  "preDeployCommand": "npm ci",          // 选填
  "postDeployCommand": "pm2 reload app"  // 选填
}

Response:
{
  "success": true,
  "data": { ... },
  "message": "项目环境配置更新成功"
}
```

#### 4.5 删除项目环境配置（仅管理员）
```
DELETE /api/project-environments/:id
Authorization: Bearer <token>

Response:
{
  "success": true,
  "message": "项目环境配置删除成功"
}

错误情况:
{
  "success": false,
  "error": "该配置下存在部署记录，无法删除"
}
```

#### 4.6 启用/禁用项目环境配置（仅管理员）
```
POST /api/project-environments/:id/toggle
Authorization: Bearer <token>

Response:
{
  "success": true,
  "data": {
    "id": 1,
    "enabled": false  // 切换后的状态
  },
  "message": "配置已禁用"
}
```

---

### 5. 部署模块 (Deployments)

#### 5.1 获取部署记录列表（分页）
```
GET /api/deployments?page=1&pageSize=10&projectEnvironmentId=1&status=success
Authorization: Bearer <token>

Query参数:
- page: 页码，默认1
- pageSize: 每页数量，默认10
- projectEnvironmentId: 按项目环境配置过滤
- status: 按状态过滤 (pending/running/success/failed)

Response:
{
  "success": true,
  "data": {
    "list": [
      {
        "id": 1,
        "status": "success",
        "commitHash": "abc1234",
        "commitMessage": "feat: add new feature",
        "startedAt": "2025-11-28T10:00:00.000Z",
        "finishedAt": "2025-11-28T10:02:30.000Z",
        "createdAt": "2025-11-28T10:00:00.000Z",
        "project": {
          "id": 1,
          "name": "FM前端项目",
          "projectKey": "fm-frontend"
        },
        "environment": {
          "id": 1,
          "name": "生产环境"
        },
        "user": {
          "id": 1,
          "username": "admin",
          "name": "系统管理员"
        }
      }
    ],
    "pagination": {
      "page": 1,
      "pageSize": 10,
      "total": 50,
      "totalPages": 5
    }
  }
}
```

#### 5.2 获取项目的部署记录
```
GET /api/projects/:projectId/deployments?page=1&pageSize=10
Authorization: Bearer <token>

Response:
{
  "success": true,
  "data": {
    "list": [
      {
        "id": 1,
        "status": "success",
        "commitHash": "abc1234",
        "commitMessage": "feat: add new feature",
        "startedAt": "2025-11-28T10:00:00.000Z",
        "finishedAt": "2025-11-28T10:02:30.000Z",
        "createdAt": "2025-11-28T10:00:00.000Z",
        "environment": {
          "id": 1,
          "name": "生产环境"
        },
        "user": {
          "id": 1,
          "username": "admin",
          "name": "系统管理员"
        }
      }
    ],
    "pagination": { ... }
  }
}
```

#### 5.3 获取部署详情
```
GET /api/deployments/:id
Authorization: Bearer <token>

Response:
{
  "success": true,
  "data": {
    "id": 1,
    "status": "success",
    "commitHash": "abc1234567890",
    "commitMessage": "feat: add new feature",
    "startedAt": "2025-11-28T10:00:00.000Z",
    "finishedAt": "2025-11-28T10:02:30.000Z",
    "errorMessage": null,
    "createdAt": "2025-11-28T10:00:00.000Z",
    "projectEnvironment": {
      "id": 1,
      "deployPath": "/var/www/fm-frontend",
      "branch": "master",
      "project": {
        "id": 1,
        "name": "FM前端项目",
        "projectKey": "fm-frontend",
        "type": "frontend"
      },
      "environment": {
        "id": 1,
        "name": "生产环境",
        "sshHost": "192.168.1.100"
      }
    },
    "user": {
      "id": 1,
      "username": "admin",
      "name": "系统管理员"
    }
  }
}
```

#### 5.4 创建部署任务
```
POST /api/deployments
Authorization: Bearer <token>
Content-Type: application/json

Request:
{
  "projectEnvironmentId": 1  // 必填，项目环境配置ID
}

Response:
{
  "success": true,
  "data": {
    "id": 10,
    "status": "pending",
    "project": {
      "id": 1,
      "name": "FM前端项目"
    },
    "environment": {
      "id": 1,
      "name": "生产环境"
    }
  },
  "message": "部署任务已创建"
}

错误情况:
{
  "success": false,
  "error": "该项目环境配置已禁用"
}
或
{
  "success": false,
  "error": "该项目环境已有部署任务正在执行"
}
```

#### 5.5 获取部署日志
```
GET /api/deployments/:id/logs
Authorization: Bearer <token>

Response:
{
  "success": true,
  "data": {
    "deploymentId": 1,
    "status": "running",
    "logs": [
      {
        "id": 1,
        "logType": "info",
        "message": "正在连接服务器...",
        "timestamp": "2025-11-28T10:00:01.000Z"
      },
      {
        "id": 2,
        "logType": "info",
        "message": "已连接到服务器: 192.168.1.100",
        "timestamp": "2025-11-28T10:00:02.000Z"
      },
      {
        "id": 3,
        "logType": "stdout",
        "message": "Already up to date.",
        "timestamp": "2025-11-28T10:00:05.000Z"
      },
      {
        "id": 4,
        "logType": "info",
        "message": "✅ 部署成功!",
        "timestamp": "2025-11-28T10:02:30.000Z"
      }
    ]
  }
}

日志类型 (logType):
- info: 信息日志
- stdout: 标准输出
- stderr: 标准错误
- error: 错误日志
```

#### 5.6 回滚部署
```
POST /api/deployments/:id/rollback
Authorization: Bearer <token>

Response:
{
  "success": true,
  "data": {
    "id": 11,
    "status": "pending",
    "originalDeploymentId": 1
  },
  "message": "回滚任务已创建"
}

错误情况:
{
  "success": false,
  "error": "只能回滚成功的部署"
}
```

#### 5.7 取消部署
```
POST /api/deployments/:id/cancel
Authorization: Bearer <token>

Response:
{
  "success": true,
  "message": "部署已取消"
}

错误情况:
{
  "success": false,
  "error": "只能取消待执行或执行中的部署"
}
```

---

### 6. WebSocket实时通信

#### 6.1 连接地址
```
ws://localhost:3000/ws?token=<jwt_token>
```

**连接参数**:
- token: JWT认证token（必填，通过URL参数传递）

#### 6.2 连接流程
```javascript
// 示例：使用 web_socket_channel 包
const ws = new WebSocket('ws://localhost:3000/ws?token=' + token);

// 连接成功后会收到
{
  "type": "connected",
  "payload": {
    "message": "连接成功",
    "userId": 1,
    "username": "admin"
  }
}
```

#### 6.3 消息类型

**客户端发送的消息**:

```javascript
// 订阅部署日志
{
  "type": "subscribe_deployment",
  "payload": {
    "deploymentId": 1
  }
}

// 取消订阅
{
  "type": "unsubscribe_deployment",
  "payload": {
    "deploymentId": 1
  }
}

// 心跳检测
{
  "type": "ping",
  "payload": {}
}
```

**服务端返回的消息**:

```javascript
// 订阅确认
{
  "type": "subscribed",
  "payload": {
    "deploymentId": 1
  }
}

// 取消订阅确认
{
  "type": "unsubscribed",
  "payload": {
    "deploymentId": 1
  }
}

// 实时部署日志
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

// 心跳响应
{
  "type": "pong",
  "payload": {}
}
```

#### 6.4 日志步骤 (step) 说明
| step | 说明 |
|------|------|
| connect | SSH连接阶段 |
| check | 检查部署目录 |
| pre_deploy | 部署前命令 |
| git | Git操作 |
| build | 构建阶段 |
| post_deploy | 部署后命令 |
| complete | 部署完成 |
| error | 错误 |
| rollback | 回滚操作 |

#### 6.5 移动端WebSocket使用建议
```dart
// Flutter示例使用 web_socket_channel
import 'package:web_socket_channel/web_socket_channel.dart';

class DeploymentWebSocket {
  WebSocketChannel? _channel;

  void connect(String token) {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:3000/ws?token=$token'),
    );

    _channel?.stream.listen((message) {
      final data = jsonDecode(message);
      switch (data['type']) {
        case 'connected':
          print('WebSocket连接成功');
          break;
        case 'deployment_log':
          // 处理部署日志
          handleDeploymentLog(data['payload']);
          break;
      }
    });
  }

  void subscribeDeployment(int deploymentId) {
    _channel?.sink.add(jsonEncode({
      'type': 'subscribe_deployment',
      'payload': {'deploymentId': deploymentId}
    }));
  }

  void disconnect() {
    _channel?.sink.close();
  }
}
```

---

## 数据模型

### User（用户）
```typescript
{
  id: number;
  username: string;
  name: string;
  role: 'admin' | 'developer';
  createdAt: Date;
}
```

### Project（项目）
```typescript
{
  id: number;
  name: string;
  projectKey: string;       // 唯一标识
  type: 'frontend' | 'backend';
  gitRepo?: string;
  description?: string;
  createdAt: Date;
  updatedAt: Date;
}
```

### Environment（服务器环境）
```typescript
{
  id: number;
  name: string;             // 如：生产环境、测试环境
  sshHost: string;
  sshPort: number;
  sshUser: string;
  sshKeyPath: string;       // 私钥路径
  description?: string;
  createdAt: Date;
}
```

### ProjectEnvironment（项目环境配置）
```typescript
{
  id: number;
  projectId: number;
  environmentId: number;
  deployPath: string;       // 部署目录
  branch: string;           // Git分支
  buildCommand?: string;    // 构建命令
  preDeployCommand?: string;  // 部署前执行命令
  postDeployCommand?: string; // 部署后执行命令
  enabled: boolean;
}
```

### Deployment（部署记录）
```typescript
{
  id: number;
  projectEnvironmentId: number;
  userId: number;
  status: 'pending' | 'running' | 'success' | 'failed' | 'cancelled';
  commitHash?: string;
  commitMessage?: string;
  startedAt?: Date;
  finishedAt?: Date;
  errorMessage?: string;
  createdAt: Date;
}
```

---

## 移动端页面规划

### 1. 登录页 (LoginPage)
- 用户名/密码输入
- 记住登录状态
- 显示登录错误信息

### 2. 首页/仪表盘 (DashboardPage)
- 显示最近部署记录
- 快速部署入口
- 系统状态概览

### 3. 项目列表页 (ProjectsPage)
- 项目列表展示
- 按类型筛选（前端/后端）
- 搜索功能
- 下拉刷新

### 4. 项目详情页 (ProjectDetailPage)
- 项目基本信息
- 关联的环境配置列表
- 每个环境的部署按钮
- 最近部署记录

### 5. 部署执行页 (DeploymentPage)
- 选择部署环境
- 确认部署信息
- 实时日志展示
- 部署进度显示

### 6. 部署记录页 (DeploymentHistoryPage)
- 部署记录列表
- 按状态筛选
- 查看详情
- 回滚操作

### 7. 环境管理页 (EnvironmentsPage)
- 服务器环境列表
- 添加/编辑环境
- SSH连接测试

### 8. 设置页 (SettingsPage)
- 个人信息
- 修改密码
- 退出登录

---

## 开发测试账号

- **管理员**: `admin` / `admin123`
- **开发者**: `developer` / `dev123`

---

## 错误码说明

| HTTP状态码 | 说明 |
|-----------|------|
| 200 | 成功 |
| 201 | 创建成功 |
| 400 | 请求参数错误 |
| 401 | 未认证/Token无效 |
| 403 | 权限不足 |
| 404 | 资源不存在 |
| 500 | 服务器内部错误 |

---

## 开发注意事项

1. **Token管理**:
   - Token有效期7天
   - 需要在本地安全存储Token
   - 401错误时需要跳转到登录页

2. **网络请求**:
   - 所有API请求需添加 `Authorization: Bearer <token>` 头
   - 建议使用拦截器统一处理认证和错误

3. **用户角色**:
   - `admin`: 可以管理项目、环境、执行部署
   - `developer`: 只能查看和执行部署

4. **部署流程**:
   - 选择项目 → 选择环境 → 确认部署 → 查看实时日志

5. **WebSocket连接**:
   - 部署时需要建立WebSocket连接接收实时日志
   - 连接地址: `ws://localhost:3000/ws?token=<jwt_token>`
   - 详细使用说明见上方 "6. WebSocket实时通信" 章节

---

## 后端开发进度

| 模块 | 状态 | 说明 |
|------|------|------|
| 认证模块 | ✅ 完成 | 登录、获取用户信息、修改密码 |
| 项目管理 | ✅ 完成 | CRUD操作、分页查询 |
| 环境管理 | ✅ 完成 | CRUD操作、SSH连接测试 |
| 项目环境配置 | ✅ 完成 | CRUD操作、启用/禁用 |
| 部署模块 | ✅ 完成 | 创建部署、查看日志、回滚、取消 |
| WebSocket | ✅ 完成 | 实时日志推送、部署订阅 |
| SSH服务 | ✅ 完成 | 远程命令执行、Git操作 |

**🎉 后端核心功能已全部完成！移动端开发可以并行进行。**

---

## 联系方式

如有API接口问题或需要新增接口，请与后端开发同步沟通。

后端代码位置: `/Users/li/Desktop/work7_8/www/fm-deploy/backend`
