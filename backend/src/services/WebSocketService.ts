import { Server as HTTPServer } from 'http';
import { WebSocket, WebSocketServer } from 'ws';
import { verify } from 'jsonwebtoken';
import { runningDeployments } from '../controllers/DeploymentController';
import { logger } from '../utils/logger';
import { getJwtSecret, JWT_VERIFY_OPTIONS } from '../config/auth';

interface AuthenticatedWebSocket extends WebSocket {
  userId?: number;
  username?: string;
  isAlive?: boolean;
  subscribedDeployments?: Set<number>;
}

interface WebSocketMessage {
  type: string;
  payload: Record<string, unknown>;
}

export class WebSocketService {
  private wss: WebSocketServer;
  private clients: Map<number, Set<AuthenticatedWebSocket>> = new Map(); // userId -> Set of WebSocket connections

  constructor(server: HTTPServer) {
    this.wss = new WebSocketServer({ server, path: '/ws' });
    this.init();
  }

  private init(): void {
    this.wss.on('connection', (ws: AuthenticatedWebSocket, req) => {
      // 从URL参数获取token
      const url = new URL(req.url || '', `ws://${req.headers.host}`);
      const token = url.searchParams.get('token');

      if (!token) {
        ws.close(4001, '需要认证');
        return;
      }

      // 验证token (使用统一配置)
      try {
        const decoded = verify(token, getJwtSecret(), JWT_VERIFY_OPTIONS) as {
          id: number;
          username: string;
        };

        ws.userId = decoded.id;
        ws.username = decoded.username;
        ws.isAlive = true;
        ws.subscribedDeployments = new Set();

        // 添加到客户端列表
        if (!this.clients.has(decoded.id)) {
          this.clients.set(decoded.id, new Set());
        }
        this.clients.get(decoded.id)!.add(ws);

        logger.info(`WebSocket客户端连接: ${decoded.username} (ID: ${decoded.id})`);

        // 发送连接成功消息
        this.sendToClient(ws, {
          type: 'connected',
          payload: {
            message: '连接成功',
            userId: decoded.id,
            username: decoded.username,
          },
        });

      } catch {
        ws.close(4001, 'Token无效');
        return;
      }

      // 处理消息
      ws.on('message', (data) => {
        this.handleMessage(ws, data.toString());
      });

      // 处理心跳
      ws.on('pong', () => {
        ws.isAlive = true;
      });

      // 处理断开连接
      ws.on('close', () => {
        this.handleDisconnect(ws);
      });

      // 处理错误
      ws.on('error', (error) => {
        logger.error(`WebSocket错误: ${error.message}`);
      });
    });

    // 心跳检测（每30秒）
    setInterval(() => {
      this.wss.clients.forEach((ws: WebSocket) => {
        const authWs = ws as AuthenticatedWebSocket;
        if (authWs.isAlive === false) {
          return authWs.terminate();
        }
        authWs.isAlive = false;
        authWs.ping();
      });
    }, 30000);

    logger.info('WebSocket服务已启动');
  }

  /**
   * 处理客户端消息
   */
  private handleMessage(ws: AuthenticatedWebSocket, data: string): void {
    try {
      const message: WebSocketMessage = JSON.parse(data);

      switch (message.type) {
        case 'subscribe_deployment':
          this.subscribeToDeployment(ws, message.payload.deploymentId as number);
          break;

        case 'unsubscribe_deployment':
          this.unsubscribeFromDeployment(ws, message.payload.deploymentId as number);
          break;

        case 'ping':
          this.sendToClient(ws, { type: 'pong', payload: {} });
          break;

        default:
          logger.warn(`未知消息类型: ${message.type}`);
      }
    } catch (error) {
      logger.error(`处理WebSocket消息失败: ${error}`);
    }
  }

  /**
   * 订阅部署日志
   */
  private subscribeToDeployment(ws: AuthenticatedWebSocket, deploymentId: number): void {
    if (!deploymentId) return;

    ws.subscribedDeployments?.add(deploymentId);

    // 如果部署正在进行，订阅日志事件
    const deploymentService = runningDeployments.get(deploymentId);
    if (deploymentService) {
      const logHandler = (log: Record<string, unknown>) => {
        if (ws.subscribedDeployments?.has(deploymentId)) {
          this.sendToClient(ws, {
            type: 'deployment_log',
            payload: log,
          });
        }
      };

      deploymentService.on('log', logHandler);

      // 当客户端断开时移除监听
      ws.on('close', () => {
        deploymentService.removeListener('log', logHandler);
      });
    }

    this.sendToClient(ws, {
      type: 'subscribed',
      payload: { deploymentId },
    });

    logger.info(`用户 ${ws.username} 订阅了部署 ${deploymentId}`);
  }

  /**
   * 取消订阅部署日志
   */
  private unsubscribeFromDeployment(ws: AuthenticatedWebSocket, deploymentId: number): void {
    if (!deploymentId) return;

    ws.subscribedDeployments?.delete(deploymentId);

    this.sendToClient(ws, {
      type: 'unsubscribed',
      payload: { deploymentId },
    });

    logger.info(`用户 ${ws.username} 取消订阅部署 ${deploymentId}`);
  }

  /**
   * 处理客户端断开连接
   */
  private handleDisconnect(ws: AuthenticatedWebSocket): void {
    if (ws.userId) {
      const userClients = this.clients.get(ws.userId);
      if (userClients) {
        userClients.delete(ws);
        if (userClients.size === 0) {
          this.clients.delete(ws.userId);
        }
      }
      logger.info(`WebSocket客户端断开: ${ws.username} (ID: ${ws.userId})`);
    }
  }

  /**
   * 向单个客户端发送消息
   */
  private sendToClient(ws: AuthenticatedWebSocket, message: WebSocketMessage): void {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(message));
    }
  }

  /**
   * 向用户的所有客户端发送消息
   */
  public sendToUser(userId: number, message: WebSocketMessage): void {
    const userClients = this.clients.get(userId);
    if (userClients) {
      userClients.forEach((ws) => {
        this.sendToClient(ws, message);
      });
    }
  }

  /**
   * 向订阅了指定部署的所有客户端发送消息
   */
  public sendToDeploymentSubscribers(deploymentId: number, message: WebSocketMessage): void {
    this.wss.clients.forEach((ws: WebSocket) => {
      const authWs = ws as AuthenticatedWebSocket;
      if (authWs.subscribedDeployments?.has(deploymentId)) {
        this.sendToClient(authWs, message);
      }
    });
  }

  /**
   * 广播消息给所有已认证的客户端
   */
  public broadcast(message: WebSocketMessage): void {
    this.wss.clients.forEach((ws: WebSocket) => {
      const authWs = ws as AuthenticatedWebSocket;
      if (authWs.userId) {
        this.sendToClient(authWs, message);
      }
    });
  }

  /**
   * 获取在线用户数
   */
  public getOnlineUserCount(): number {
    return this.clients.size;
  }

  /**
   * 获取总连接数
   */
  public getConnectionCount(): number {
    return this.wss.clients.size;
  }
}

// 单例实例
let wsService: WebSocketService | null = null;

/**
 * 初始化WebSocket服务
 */
export function initWebSocketService(server: HTTPServer): WebSocketService {
  if (!wsService) {
    wsService = new WebSocketService(server);
  }
  return wsService;
}

/**
 * 获取WebSocket服务实例
 */
export function getWebSocketService(): WebSocketService | null {
  return wsService;
}
