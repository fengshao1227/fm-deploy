# 快速开始指南

## 📝 当前进度

✅ 已完成:
- 项目结构创建
- Node.js后端项目初始化
- TypeScript配置
- 数据库模型定义
- 基础配置文件

⏳ 待完成:
- SSH服务和部署核心逻辑
- REST API接口
- WebSocket实时通信
- Flutter移动应用
- 测试和文档

## 🚀 下一步操作

### 1. 安装后端依赖

```bash
cd fm-deploy/backend
npm install
```

### 2. 配置数据库

#### 2.1 安装PostgreSQL

**macOS (使用Homebrew)**
```bash
brew install postgresql
brew services start postgresql
```

**Ubuntu/Debian**
```bash
sudo apt-get install postgresql postgresql-contrib
sudo systemctl start postgresql
```

#### 2.2 创建数据库

```bash
# 进入PostgreSQL
psql postgres

# 创建数据库
CREATE DATABASE fm_deploy;

# 创建用户(可选)
CREATE USER fm_deploy_user WITH ENCRYPTED PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE fm_deploy TO fm_deploy_user;

# 退出
\q
```

### 3. 配置Redis

**macOS (使用Homebrew)**
```bash
brew install redis
brew services start redis
```

**Ubuntu/Debian**
```bash
sudo apt-get install redis-server
sudo systemctl start redis
```

### 4. 配置环境变量

```bash
cd fm-deploy/backend
cp .env.example .env
```

编辑 `.env` 文件：

```env
NODE_ENV=development
PORT=3000

JWT_SECRET=$(openssl rand -base64 32)  # 生成随机密钥

DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres  # 或您创建的用户
DB_PASSWORD=  # 您的密码
DB_NAME=fm_deploy

REDIS_HOST=localhost
REDIS_PORT=6379

SSH_KEYS_PATH=./ssh-keys  # SSH密钥存储路径
```

### 5. 创建SSH密钥存储目录

```bash
mkdir -p fm-deploy/backend/ssh-keys
chmod 700 fm-deploy/backend/ssh-keys
```

### 6. 复制SSH密钥

将您的SSH密钥文件(如 `French-FM-SSR.pem`)复制到 `ssh-keys` 目录：

```bash
cp /path/to/French-FM-SSR.pem fm-deploy/backend/ssh-keys/
chmod 600 fm-deploy/backend/ssh-keys/French-FM-SSR.pem
```

### 7. 启动开发服务器

```bash
cd fm-deploy/backend
npm run dev
```

您应该看到类似输出：
```
[2025-01-28 14:58:00] [info]: 正在连接数据库...
[2025-01-28 14:58:01] [info]: 数据库连接成功
[2025-01-28 14:58:01] [info]: 服务器运行在端口 3000
[2025-01-28 14:58:01] [info]: 环境: development
[2025-01-28 14:58:01] [info]: WebSocket已启用
```

### 8. 测试API

#### 健康检查
```bash
curl http://localhost:3000/health
```

预期响应：
```json
{
  "status": "ok",
  "timestamp": "2025-01-28T06:58:00.000Z",
  "uptime": 1.234
}
```

## 🗄️ 初始化数据

### 创建管理员用户

当后端完全开发完成后，您可以通过种子文件创建初始用户：

```bash
cd fm-deploy/backend
npm run seed
```

或手动插入：

```sql
-- 连接数据库
psql -d fm_deploy

-- 创建管理员用户(密码: admin123)
INSERT INTO users (username, password_hash, name, role, created_at, updated_at)
VALUES (
  'admin',
  '$2b$10$XQq.EXAMPLE.HASH',  -- 需要用bcrypt生成
  '系统管理员',
  'admin',
  NOW(),
  NOW()
);
```

### 配置环境

```sql
-- 插入测试环境
INSERT INTO environments (name, ssh_host, ssh_port, ssh_user, ssh_key_path, description, created_at, updated_at)
VALUES (
  '测试环境',
  '15.236.225.30',
  22,
  'ubuntu',
  'ssh-keys/French-FM-SSR.pem',
  'AWS法国测试服务器',
  NOW(),
  NOW()
);
```

### 配置项目

```sql
-- 插入store-mix项目
INSERT INTO projects (name, project_key, type, git_repo, description, created_at, updated_at)
VALUES (
  'Store Mix',
  'store-mix',
  'frontend',
  '阿里云code仓库地址',
  'Taro多端商城应用',
  NOW(),
  NOW()
);

-- 配置项目环境
INSERT INTO project_environments (
  project_id,
  environment_id,
  deploy_path,
  branch,
  pre_deploy_command,
  build_command,
  post_deploy_command,
  enabled,
  created_at,
  updated_at
) VALUES (
  1,  -- store-mix项目ID
  1,  -- 测试环境ID
  '/var/www/bottegaveneta/ssr-store',
  'master',
  'git pull',
  'npm install && npm run build:h5',
  NULL,
  true,
  NOW(),
  NOW()
);
```

## 🔍 验证安装

### 检查数据库连接

```bash
psql -d fm_deploy -c "SELECT tablename FROM pg_tables WHERE schemaname = 'public';"
```

应该看到所有表：
- users
- environments
- projects
- project_environments
- deployments
- deployment_logs
- deployment_snapshots

### 检查Redis连接

```bash
redis-cli ping
```

应该返回：
```
PONG
```

## 📚 下一步学习

1. [API文档](./API.md) - 了解所有API接口
2. [部署流程](./DEPLOYMENT.md) - 理解部署逻辑
3. [数据库设计](./DATABASE.md) - 深入了解数据结构

## ⚠️ 注意事项

1. **开发环境**
   - 数据库synchronize设置为true，会自动创建表
   - 生产环境必须设置为false，使用migration

2. **SSH密钥安全**
   - 确保ssh-keys目录权限为700
   - 密钥文件权限为600
   - 不要将密钥提交到Git仓库

3. **JWT密钥**
   - 生产环境必须使用强随机密钥
   - 不要使用示例中的密钥

## 🐛 常见问题

### 数据库连接失败

```bash
# 检查PostgreSQL是否运行
pg_isready

# 检查端口
lsof -i :5432

# 查看PostgreSQL日志
tail -f /usr/local/var/log/postgres.log
```

### Redis连接失败

```bash
# 检查Redis是否运行
redis-cli ping

# 检查端口
lsof -i :6379
```

### TypeScript编译错误

```bash
# 清除构建缓存
rm -rf dist/
npm run build
```

---

**准备好了？** 继续开发核心功能或等待完整系统开发完成！
