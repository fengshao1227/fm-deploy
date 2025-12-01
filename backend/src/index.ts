import 'reflect-metadata';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import dotenv from 'dotenv';
import { createServer } from 'http';
import { AppDataSource } from './config/database';
import { initWebSocketService } from './services/WebSocketService';
import routes from './routes';
import { errorHandler } from './middlewares/errorHandler';
import { logger } from './utils/logger';

// 加载环境变量
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// 中间件
app.use(helmet());

// CORS配置 - 区分开发/生产环境
const corsOptions = {
  origin: (() => {
    const isProduction = process.env.NODE_ENV === 'production';
    const corsOrigin = process.env.CORS_ORIGIN;

    if (isProduction) {
      // 生产环境：必须显式配置白名单
      if (!corsOrigin) {
        logger.warn('警告: 生产环境未配置 CORS_ORIGIN，将拒绝所有跨域请求');
        return false;
      }
      return corsOrigin.split(',').map((o) => o.trim()).filter(Boolean);
    }

    // 开发环境：允许所有来源
    return true;
  })(),
  credentials: true,
};
app.use(cors(corsOptions));
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 健康检查
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

// API路由
app.use('/api', routes);

// 错误处理中间件
app.use(errorHandler);

// 创建HTTP服务器
const httpServer = createServer(app);

// 启动服务器
async function startServer() {
  try {
    // 连接数据库
    logger.info('正在连接数据库...');
    await AppDataSource.initialize();
    logger.info('数据库连接成功');

    // 初始化WebSocket服务
    initWebSocketService(httpServer);

    // 启动HTTP服务器
    httpServer.listen(PORT, () => {
      logger.info(`服务器运行在端口 ${PORT}`);
      logger.info(`环境: ${process.env.NODE_ENV}`);
      logger.info(`WebSocket服务: ws://localhost:${PORT}/ws`);
    });
  } catch (error) {
    logger.error('服务器启动失败:', error);
    process.exit(1);
  }
}

// 优雅关闭
process.on('SIGTERM', async () => {
  logger.info('收到SIGTERM信号，正在关闭服务器...');
  httpServer.close(async () => {
    await AppDataSource.destroy();
    logger.info('服务器已关闭');
    process.exit(0);
  });
});

startServer();
