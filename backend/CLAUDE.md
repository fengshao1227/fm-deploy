[根目录](../CLAUDE.md) > **backend**

# Backend - Node.js 后端服务

> AI 上下文文档 | 最后更新: 2025-12-01T10:20:34+08:00

## 模块职责

后端服务负责提供 RESTful API 接口，处理用户认证、项目管理、环境配置、部署执行、实时日志推送等核心业务逻辑。

## 技术栈

- **运行时**: Node.js >= 18
- **框架**: Express.js
- **语言**: TypeScript
- **ORM**: TypeORM
- **数据库**: MySQL
- **缓存/队列**: Redis + Bull
- **实时通信**: WebSocket (原生 ws 库)
- **认证**: JWT (jsonwebtoken)
- **SSH**: node-ssh / ssh2

## 入口与启动

**入口文件**: `src/index.ts`

```bash
# 开发模式 (热重载)
npm run dev

# 生产模式
npm run build && npm start

# 数据库迁移
npm run migrate

# 种子数据
npm run seed
```

## 目录结构

```
backend/
├── src/
│   ├── index.ts              # 应用入口
│   ├── config/               # 配置文件
│   │   ├── database.ts       # 数据库配置 (TypeORM DataSource)
│   │   ├── redis.ts          # Redis 配置
│   │   └── auth.ts           # 认证配置
│   ├── controllers/          # 控制器 (处理 HTTP 请求)
│   │   ├── AuthController.ts
│   │   ├── ProjectController.ts
│   │   ├── EnvironmentController.ts
│   │   ├── ProjectEnvironmentController.ts
│   │   └── DeploymentController.ts
│   ├── models/               # 数据模型 (TypeORM 实体)
│   │   ├── User.ts
│   │   ├── Project.ts
│   │   ├── Environment.ts
│   │   ├── ProjectEnvironment.ts
│   │   ├── Deployment.ts
│   │   ├── DeploymentLog.ts
│   │   └── DeploymentSnapshot.ts
│   ├── services/             # 业务服务层
│   │   ├── DeploymentService.ts   # 部署核心逻辑
│   │   ├── SSHService.ts          # SSH 连接服务
│   │   ├── LocalBuildService.ts   # 本地构建服务
│   │   └── WebSocketService.ts    # WebSocket 服务
│   ├── routes/               # 路由定义
│   │   └── index.ts
│   ├── middlewares/          # 中间件
│   │   ├── auth.ts           # 认证中间件
│   │   └── errorHandler.ts   # 错误处理
│   ├── utils/                # 工具函数
│   │   ├── logger.ts         # 日志工具 (Winston)
│   │   └── validation.ts     # 参数验证 (Joi)
│   └── seeds/                # 种子数据
│       └── index.ts
├── package.json
├── tsconfig.json
└── .env.example
```

## 对外接口

### 认证 API

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/auth/login` | 用户登录 |
| GET | `/api/auth/me` | 获取当前用户信息 |
| POST | `/api/auth/change-password` | 修改密码 |

### 项目管理 API

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/projects/all` | 获取所有项目 |
| GET | `/api/projects` | 分页获取项目列表 |
| GET | `/api/projects/:id` | 获取项目详情 |
| POST | `/api/projects` | 创建项目 (admin) |
| PUT | `/api/projects/:id` | 更新项目 (admin) |
| DELETE | `/api/projects/:id` | 删除项目 (admin) |

### 环境管理 API

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/environments/all` | 获取所有环境 |
| GET | `/api/environments` | 分页获取环境列表 |
| GET | `/api/environments/:id` | 获取环境详情 |
| POST | `/api/environments` | 创建环境 (admin) |
| PUT | `/api/environments/:id` | 更新环境 (admin) |
| DELETE | `/api/environments/:id` | 删除环境 (admin) |
| POST | `/api/environments/:id/test` | 测试 SSH 连接 |

### 项目环境配置 API

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/projects/:projectId/environments` | 获取项目的环境配置列表 |
| POST | `/api/projects/:projectId/environments` | 创建项目环境配置 |
| GET | `/api/project-environments/:id` | 获取配置详情 |
| PUT | `/api/project-environments/:id` | 更新配置 |
| DELETE | `/api/project-environments/:id` | 删除配置 |
| POST | `/api/project-environments/:id/toggle` | 启用/禁用配置 |

### 部署管理 API

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/deployments` | 获取部署列表 |
| GET | `/api/deployments/:id` | 获取部署详情 |
| POST | `/api/deployments` | 创建并执行部署 |
| GET | `/api/deployments/:id/logs` | 获取部署日志 |
| POST | `/api/deployments/:id/rollback` | 回滚部署 |
| POST | `/api/deployments/:id/cancel` | 取消部署 |
| GET | `/api/projects/:projectId/deployments` | 获取项目的部署历史 |

### WebSocket

- **端点**: `ws://localhost:3000/ws`
- **用途**: 实时推送部署日志
- **消息格式**:
  ```json
  {
    "type": "deployment_log",
    "data": {
      "deploymentId": 1,
      "step": "build",
      "logType": "stdout",
      "message": "构建中...",
      "timestamp": "2025-01-28T10:00:00.000Z"
    }
  }
  ```

## 关键依赖与配置

### 主要依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| express | ^4.18.2 | Web 框架 |
| typeorm | ^0.3.17 | ORM |
| mysql2 | ^3.6.5 | MySQL 驱动 |
| ioredis | ^5.3.2 | Redis 客户端 |
| bull | ^4.12.0 | 任务队列 |
| jsonwebtoken | ^9.0.2 | JWT 认证 |
| node-ssh | ^13.1.0 | SSH 连接 |
| socket.io | ^4.6.2 | WebSocket |
| winston | ^3.11.0 | 日志 |
| joi | ^17.11.0 | 参数验证 |

### 环境变量

```env
NODE_ENV=development
PORT=3000
CORS_ORIGIN=http://localhost:8080

JWT_SECRET=your-jwt-secret
JWT_EXPIRES_IN=7d

DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=password
DB_NAME=fm_deploy

REDIS_HOST=localhost
REDIS_PORT=6379

WORKSPACE_ROOT=./.workspace
```

## 数据模型

### User (用户)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | number | 主键 |
| username | string | 用户名 |
| password_hash | string | 密码哈希 |
| name | string | 显示名称 |
| role | enum | 角色 (admin/developer) |

### Project (项目)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | number | 主键 |
| name | string | 项目名称 |
| project_key | string | 项目标识 (唯一) |
| type | enum | 类型 (frontend/backend) |
| git_repo | string | Git 仓库地址 |
| description | text | 描述 |

### Environment (环境)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | number | 主键 |
| name | string | 环境名称 |
| ssh_host | string | SSH 主机 |
| ssh_port | number | SSH 端口 |
| ssh_user | string | SSH 用户 |
| ssh_key_path | string | SSH 密钥路径 |

### Deployment (部署记录)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | number | 主键 |
| project_environment_id | number | 项目环境配置 ID |
| user_id | number | 执行用户 ID |
| status | enum | 状态 (pending/running/success/failed/rollback) |
| commit_hash | string | Git 提交哈希 |
| commit_message | text | 提交信息 |
| started_at | timestamp | 开始时间 |
| finished_at | timestamp | 结束时间 |
| error_message | text | 错误信息 |

## 测试与质量

```bash
# ESLint 检查
npm run lint

# 代码格式化
npm run format

# 运行测试 (待实现)
npm test
```

## 常见问题 (FAQ)

### 1. 数据库连接失败
- 检查 MySQL 服务是否运行
- 确认 `.env` 中的数据库配置正确
- 确保数据库已创建

### 2. SSH 连接失败
- 检查 SSH 密钥路径是否正确
- 确认密钥文件权限为 600
- 验证目标服务器可达

### 3. WebSocket 连接断开
- 检查 CORS 配置
- 确认客户端 Token 有效

## 相关文件清单

- `src/index.ts` - 应用入口
- `src/routes/index.ts` - 路由定义
- `src/config/database.ts` - 数据库配置
- `src/services/DeploymentService.ts` - 部署核心逻辑
- `src/services/SSHService.ts` - SSH 操作封装
- `package.json` - 依赖和脚本

## 变更记录 (Changelog)

### 2025-12-01
- 初始化模块 AI 上下文文档
