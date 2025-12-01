# 测试指南

## 🧪 第一步：测试认证功能

### 准备工作

1. **安装依赖**
```bash
cd /Users/li/Desktop/work7_8/www/fm-deploy/backend
npm install
```

2. **配置环境变量**
```bash
cp .env.example .env
```

编辑 `.env` 文件，设置JWT密钥：
```env
NODE_ENV=development
PORT=3000
JWT_SECRET=your-super-secret-key-change-this
JWT_EXPIRES_IN=7d

# 数据库配置
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=
DB_NAME=fm_deploy

# Redis配置
REDIS_HOST=localhost
REDIS_PORT=6379
```

3. **创建数据库**
```bash
# 进入PostgreSQL
psql postgres

# 创建数据库
CREATE DATABASE fm_deploy;

# 退出
\q
```

4. **启动服务器**
```bash
npm run dev
```

你应该看到：
```
[2025-01-28 XX:XX:XX] [info]: 正在连接数据库...
[2025-01-28 XX:XX:XX] [info]: 数据库连接成功
[2025-01-28 XX:XX:XX] [info]: 服务器运行在端口 3000
[2025-01-28 XX:XX:XX] [info]: 环境: development
```

5. **初始化种子数据**

打开新终端：
```bash
cd /Users/li/Desktop/work7_8/www/fm-deploy/backend
npm run seed
```

你应该看到：
```
✅ 管理员用户创建成功
   用户名: admin
   密码: admin123
✅ 开发者用户创建成功
   用户名: developer
   密码: dev123
🎉 种子数据初始化完成！
```

---

## 📡 测试API

### 方式1: 使用curl

#### 1. 测试健康检查
```bash
curl http://localhost:3000/api/health
```

**预期响应:**
```json
{
  "status": "ok",
  "timestamp": "2025-01-28T07:00:00.000Z",
  "version": "1.0.0"
}
```

#### 2. 测试登录（管理员）
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "admin123"
  }'
```

**预期响应:**
```json
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

**⚠️ 重要：** 复制返回的 `token`，用于后续请求！

#### 3. 测试登录（错误密码）
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "wrongpassword"
  }'
```

**预期响应:**
```json
{
  "success": false,
  "error": "用户名或密码错误"
}
```

#### 4. 测试获取用户信息（需要token）
```bash
# 替换 YOUR_TOKEN 为上面登录返回的token
curl http://localhost:3000/api/auth/me \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**预期响应:**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "username": "admin",
    "name": "系统管理员",
    "role": "admin",
    "createdAt": "2025-01-28T07:00:00.000Z"
  }
}
```

#### 5. 测试获取用户信息（无token）
```bash
curl http://localhost:3000/api/auth/me
```

**预期响应:**
```json
{
  "success": false,
  "error": "未提供认证令牌"
}
```

#### 6. 测试修改密码
```bash
# 替换 YOUR_TOKEN
curl -X POST http://localhost:3000/api/auth/change-password \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "oldPassword": "admin123",
    "newPassword": "newpassword123"
  }'
```

**预期响应:**
```json
{
  "success": true,
  "message": "密码修改成功"
}
```

---

### 方式2: 使用Postman/Insomnia

#### 1. 导入环境变量
创建环境变量：
- `base_url`: `http://localhost:3000`
- `token`: (登录后设置)

#### 2. 创建请求集合

**请求1: 登录**
- 方法: POST
- URL: `{{base_url}}/api/auth/login`
- Headers:
  - `Content-Type: application/json`
- Body (JSON):
```json
{
  "username": "admin",
  "password": "admin123"
}
```
- 测试脚本 (Postman):
```javascript
if (pm.response.code === 200) {
    const jsonData = pm.response.json();
    pm.environment.set("token", jsonData.data.token);
}
```

**请求2: 获取用户信息**
- 方法: GET
- URL: `{{base_url}}/api/auth/me`
- Headers:
  - `Authorization: Bearer {{token}}`

**请求3: 修改密码**
- 方法: POST
- URL: `{{base_url}}/api/auth/change-password`
- Headers:
  - `Authorization: Bearer {{token}}`
  - `Content-Type: application/json`
- Body (JSON):
```json
{
  "oldPassword": "admin123",
  "newPassword": "newpassword123"
}
```

---

### 方式3: 使用VS Code REST Client插件

创建文件 `backend/tests/auth.http`:

```http
@baseUrl = http://localhost:3000
@token = YOUR_TOKEN_HERE

### 健康检查
GET {{baseUrl}}/api/health

### 登录 - 管理员
POST {{baseUrl}}/api/auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "admin123"
}

### 登录 - 开发者
POST {{baseUrl}}/api/auth/login
Content-Type: application/json

{
  "username": "developer",
  "password": "dev123"
}

### 获取用户信息
GET {{baseUrl}}/api/auth/me
Authorization: Bearer {{token}}

### 修改密码
POST {{baseUrl}}/api/auth/change-password
Authorization: Bearer {{token}}
Content-Type: application/json

{
  "oldPassword": "admin123",
  "newPassword": "newpassword123"
}

### 测试无效token
GET {{baseUrl}}/api/auth/me
Authorization: Bearer invalid_token_here
```

---

## ✅ 验收标准

测试通过的标准：

- [x] 服务器启动成功，无错误
- [x] 健康检查返回 `status: ok`
- [x] 种子数据创建成功
- [x] 使用正确密码登录成功，返回token
- [x] 使用错误密码登录失败，返回401错误
- [x] 不存在的用户登录失败
- [x] 携带有效token可以获取用户信息
- [x] 不携带token无法获取用户信息
- [x] 携带无效token返回401错误
- [x] 修改密码成功
- [x] 使用旧密码无法登录
- [x] 使用新密码可以登录

---

## 🐛 常见问题

### 1. 数据库连接失败

**错误**: `ECONNREFUSED 127.0.0.1:5432`

**解决**:
```bash
# macOS
brew services start postgresql

# Ubuntu
sudo systemctl start postgresql

# 检查PostgreSQL是否运行
pg_isready
```

### 2. JWT_SECRET未设置

**错误**: `JWT_SECRET is not defined`

**解决**: 确保 `.env` 文件存在且包含 `JWT_SECRET`

### 3. 表不存在

**错误**: `relation "users" does not exist`

**解决**:
1. 确认 `synchronize: true` 在开发环境配置中
2. 重启服务器，TypeORM会自动创建表
3. 或运行迁移: `npm run migrate`

### 4. 端口被占用

**错误**: `Error: listen EADDRINUSE: address already in use :::3000`

**解决**:
```bash
# macOS/Linux
lsof -ti:3000 | xargs kill -9

# 或更改端口
# 在.env中设置: PORT=3001
```

---

## 📊 测试结果示例

```bash
$ npm run dev
[info]: 正在连接数据库...
[info]: 数据库连接成功
[info]: 服务器运行在端口 3000

$ npm run seed
✅ 管理员用户创建成功
✅ 开发者用户创建成功

$ curl -X POST http://localhost:3000/api/auth/login \
  -d '{"username":"admin","password":"admin123"}'
{"success":true,"data":{"token":"eyJ..."}}

✅ 所有测试通过！
```

---

**准备好了吗？** 运行上面的命令测试认证功能！

测试通过后，我们将继续开发项目管理API。
