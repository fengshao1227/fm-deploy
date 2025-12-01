# 部署指南 - 部署到生产服务器

## 服务器信息
- **IP地址**: 117.72.163.3
- **用户**: root
- **数据库**: MySQL
- **端口**: 3000

---

## 🚀 快速部署步骤

### 方式1: 自动部署脚本（推荐）

在本地执行以下命令：

```bash
cd /Users/li/Desktop/work7_8/www/fm-deploy/backend

# 安装sshpass（用于SSH密码认证）
# macOS:
brew install hudochenkov/sshpass/sshpass

# 执行部署
./deploy.sh
```

部署完成后，访问：
- **API地址**: http://117.72.163.3:3000
- **健康检查**: http://117.72.163.3:3000/api/health

---

### 方式2: 手动部署（逐步执行）

#### 第1步：登录服务器

```bash
ssh root@117.72.163.3
# 密码: 1227
```

#### 第2步：安装Node.js（如果未安装）

```bash
# 检查是否已安装
node -v

# 如果未安装，执行：
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# 验证安装
node -v
npm -v
```

#### 第3步：安装PM2进程管理器

```bash
npm install -g pm2
pm2 -v
```

#### 第4步：创建部署目录

```bash
mkdir -p /var/www/fm-deploy
cd /var/www/fm-deploy
```

#### 第5步：上传代码

**在本地新开一个终端**，上传代码：

```bash
cd /Users/li/Desktop/work7_8/www/fm-deploy/backend

# 使用scp上传
scp -r package.json tsconfig.json nodemon.json .env.example src/ root@117.72.163.3:/var/www/fm-deploy/
```

#### 第6步：回到服务器，安装依赖

```bash
cd /var/www/fm-deploy
npm install
```

#### 第7步：配置环境变量

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑配置文件
vi .env
```

修改以下内容：

```env
NODE_ENV=production
PORT=3000

# 生成一个随机JWT密钥
JWT_SECRET=$(openssl rand -base64 32)
JWT_EXPIRES_IN=7d

# MySQL数据库配置
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=MyStrongPassword123!
DB_NAME=fm_deploy

# Redis配置（如果有）
REDIS_HOST=localhost
REDIS_PORT=6379
```

或者使用命令自动配置：

```bash
cat > .env << 'EOF'
NODE_ENV=production
PORT=3000
JWT_SECRET=$(openssl rand -base64 32)
JWT_EXPIRES_IN=7d

DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=MyStrongPassword123!
DB_NAME=fm_deploy

REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0

SSH_KEYS_PATH=/var/www/fm-deploy/ssh-keys
LOG_LEVEL=info
LOG_FILE=logs/app.log
CORS_ORIGIN=*
WS_PING_TIMEOUT=30000
WS_PING_INTERVAL=25000
EOF

# 实际生成JWT密钥
JWT_SECRET=$(openssl rand -base64 32)
sed -i "s/JWT_SECRET=.*/JWT_SECRET=$JWT_SECRET/g" .env
```

#### 第8步：创建MySQL数据库

```bash
mysql -uroot -pMyStrongPassword123! << EOF
CREATE DATABASE IF NOT EXISTS fm_deploy CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
SHOW DATABASES;
EOF
```

#### 第9步：编译TypeScript

```bash
npm run build

# 检查编译结果
ls -la dist/
```

#### 第10步：初始化数据库（运行种子数据）

```bash
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

#### 第11步：启动服务

```bash
# 使用PM2启动
pm2 start dist/index.js --name fm-deploy

# 查看日志
pm2 logs fm-deploy

# 查看状态
pm2 status
```

#### 第12步：保存PM2配置并设置开机自启

```bash
# 保存当前PM2进程列表
pm2 save

# 设置开机自启
pm2 startup systemd
# 按照提示执行输出的命令
```

#### 第13步：配置防火墙（如果需要）

```bash
# 允许3000端口
ufw allow 3000/tcp

# 或者使用iptables
iptables -A INPUT -p tcp --dport 3000 -j ACCEPT
```

---

## ✅ 验证部署

### 1. 检查服务状态

```bash
pm2 status
pm2 logs fm-deploy --lines 50
```

### 2. 测试API

#### 在服务器上测试

```bash
# 健康检查
curl http://localhost:3000/api/health

# 登录测试
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

#### 在本地测试

```bash
# 健康检查
curl http://117.72.163.3:3000/api/health

# 登录测试
curl -X POST http://117.72.163.3:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

---

## 📊 PM2常用命令

```bash
# 查看所有进程
pm2 list

# 查看日志
pm2 logs fm-deploy

# 重启服务
pm2 restart fm-deploy

# 停止服务
pm2 stop fm-deploy

# 删除服务
pm2 delete fm-deploy

# 监控
pm2 monit
```

---

## 🔧 故障排查

### 1. 服务无法启动

```bash
# 查看详细日志
pm2 logs fm-deploy --lines 100

# 查看错误日志
tail -f /var/www/fm-deploy/logs/error.log
```

### 2. 数据库连接失败

```bash
# 测试MySQL连接
mysql -uroot -pMyStrongPassword123! -e "SHOW DATABASES;"

# 检查数据库配置
cat .env | grep DB_
```

### 3. 端口被占用

```bash
# 查看3000端口占用
lsof -i :3000

# 或使用
netstat -tlnp | grep 3000

# 终止占用进程
kill -9 <PID>
```

### 4. 权限问题

```bash
# 确保目录权限正确
chown -R root:root /var/www/fm-deploy
chmod -R 755 /var/www/fm-deploy
```

---

## 🔄 更新部署

当代码更新后，重新部署：

```bash
# 1. 在本地上传新代码
cd /Users/li/Desktop/work7_8/www/fm-deploy/backend
scp -r src/ root@117.72.163.3:/var/www/fm-deploy/

# 2. 在服务器上重新编译和重启
ssh root@117.72.163.3
cd /var/www/fm-deploy
npm run build
pm2 restart fm-deploy
```

---

## 🎉 部署完成

部署成功后，您可以访问：

- **API基础地址**: http://117.72.163.3:3000
- **健康检查**: http://117.72.163.3:3000/api/health
- **登录接口**: http://117.72.163.3:3000/api/auth/login

**默认账户**：
- 管理员: `admin` / `admin123`
- 开发者: `developer` / `dev123`

⚠️ **重要**: 首次登录后请立即修改默认密码！

---

## 📞 需要帮助？

如果遇到问题，请提供：
1. PM2日志: `pm2 logs fm-deploy`
2. 错误日志: `cat logs/error.log`
3. 服务状态: `pm2 status`
