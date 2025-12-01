import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { AppError } from './errorHandler';
import { getJwtSecret, JWT_VERIFY_OPTIONS, isValidJwtPayload, JwtPayload } from '../config/auth';

export interface AuthRequest extends Request {
  user?: {
    id: number;
    username: string;
    role: 'admin' | 'developer';
  };
}

export const authMiddleware = (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    // 从请求头获取token
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new AppError('未提供认证令牌', 401);
    }

    const token = authHeader.substring(7); // 移除 "Bearer " 前缀

    // 验证token (使用统一配置)
    const decoded = jwt.verify(token, getJwtSecret(), JWT_VERIFY_OPTIONS);

    // 验证 payload 结构
    if (!isValidJwtPayload(decoded)) {
      throw new AppError('无效的认证令牌结构', 401);
    }

    // 将用户信息添加到请求对象
    req.user = {
      id: decoded.id,
      username: decoded.username,
      role: decoded.role,
    };

    next();
  } catch (error) {
    if (error instanceof jwt.JsonWebTokenError) {
      next(new AppError('无效的认证令牌', 401));
    } else if (error instanceof jwt.TokenExpiredError) {
      next(new AppError('认证令牌已过期', 401));
    } else {
      next(error);
    }
  }
};

// 角色检查中间件
export const requireRole = (...roles: string[]) => {
  return (req: AuthRequest, res: Response, next: NextFunction) => {
    if (!req.user) {
      return next(new AppError('未认证', 401));
    }

    if (!roles.includes(req.user.role)) {
      return next(new AppError('权限不足', 403));
    }

    next();
  };
};
