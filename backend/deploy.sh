#!/bin/bash

# Ensure the script runs from its own directory
cd "$(dirname "$0")" || exit 1

# Check for sshpass
if ! command -v sshpass &> /dev/null; then
    echo "❌ Error: sshpass is not installed."
    echo "Please install it: brew install sshpass (macOS) or apt-get install sshpass (Linux)"
    exit 1
fi

# 部署配置
SERVER_IP="117.72.163.3"
SERVER_USER="root"
SERVER_PASSWORD="1227"
DEPLOY_PATH="/var/www/fm-deploy"
APP_PORT="3000"

echo "🚀 开始部署 FM Deploy 后端服务..."

# 1. 连接服务器并创建目录
echo "📁 创建部署目录..."
sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no $SERVER_USER@$SERVER_IP "mkdir -p $DEPLOY_PATH"

# 2. 上传文件
echo "📤 上传文件到服务器..."
sshpass -p "$SERVER_PASSWORD" scp -r -o StrictHostKeyChecking=no \
  package.json \
  tsconfig.json \
  nodemon.json \
  .env.example \
  src/ \
  $SERVER_USER@$SERVER_IP:$DEPLOY_PATH/

# 3. 在服务器上执行部署命令
echo "⚙️  在服务器上配置环境..."
sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no $SERVER_USER@$SERVER_IP << 'ENDSSH'

# 进入部署目录
cd /var/www/fm-deploy

# 检查Node.js是否安装
if ! command -v node &> /dev/null; then
    echo "📦 安装Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
fi

# 检查npm是否安装
if ! command -v npm &> /dev/null; then
    echo "📦 安装npm..."
    apt-get install -y npm
fi

# 安装PM2（用于进程管理）
if ! command -v pm2 &> /dev/null; then
    echo "📦 安装PM2..."
    npm install -g pm2
fi

# 安装项目依赖
echo "📦 安装项目依赖..."
npm install

# 创建.env文件
if [ ! -f .env ]; then
    echo "⚙️  创建.env配置文件..."
    cp .env.example .env

    # 生成JWT密钥
    JWT_SECRET=$(openssl rand -base64 32)
    sed -i "s/your-secret-key-change-this-in-production/$JWT_SECRET/g" .env

    # 设置生产环境
    sed -i 's/NODE_ENV=development/NODE_ENV=production/g' .env
fi

# 编译TypeScript
echo "🔨 编译TypeScript..."
npm run build

# 创建数据库
echo "📊 创建数据库..."
mysql -uroot -pMyStrongPassword123! -e "CREATE DATABASE IF NOT EXISTS fm_deploy CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 运行种子数据
echo "🌱 初始化种子数据..."
npm run seed

# 停止旧的进程
echo "🛑 停止旧进程..."
pm2 delete fm-deploy 2>/dev/null || true

# 启动服务
echo "🚀 启动服务..."
pm2 start dist/index.js --name fm-deploy

# 保存PM2配置
pm2 save

# 设置PM2开机自启
pm2 startup systemd -u root --hp /root

echo "✅ 部署完成！"
echo "服务运行在: http://117.72.163.3:3000"
echo ""
echo "测试登录："
echo "curl -X POST http://117.72.163.3:3000/api/auth/login \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"username\":\"admin\",\"password\":\"admin123\"}'"

ENDSSH

echo ""
echo "🎉 部署完成！"
echo "📍 服务地址: http://117.72.163.3:3000"
echo "📍 健康检查: http://117.72.163.3:3000/api/health"
echo ""
echo "默认账户："
echo "  管理员 - 用户名: admin, 密码: admin123"
echo "  开发者 - 用户名: developer, 密码: dev123"
