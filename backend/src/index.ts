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

// CORS配置 - 为移动端提供完整支持
const corsOptions = {
  origin: (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
    const isProduction = process.env.NODE_ENV === 'production';
    const corsOrigin = process.env.CORS_ORIGIN;

    // 允许没有origin的请求（如移动应用、Postman等）
    if (!origin) {
      return callback(null, true);
    }

    if (isProduction) {
      // 生产环境：如果配置了白名单，检查白名单；否则允许所有
      if (corsOrigin) {
        const allowedOrigins = corsOrigin.split(',').map((o) => o.trim()).filter(Boolean);
        if (allowedOrigins.includes(origin)) {
          callback(null, true);
        } else {
          callback(new Error('CORS策略：不允许此来源'));
        }
      } else {
        // 如果没有配置白名单，允许所有来源（为了支持移动端）
        logger.warn('生产环境未配置 CORS_ORIGIN，允许所有来源以支持移动端');
        callback(null, true);
      }
    } else {
      // 开发环境：允许所有来源
      callback(null, true);
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH', 'HEAD'],
  allowedHeaders: ['Origin', 'X-Requested-With', 'Content-Type', 'Accept', 'Authorization', 'Cache-Control', 'Pragma'],
  exposedHeaders: ['X-Total-Count'],
  optionsSuccessStatus: 204 // 支持老版本浏览器
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
