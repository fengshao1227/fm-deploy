import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';

export class AppError extends Error {
  statusCode: number;
  isOperational: boolean;

  constructor(message: string, statusCode: number = 500) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }
}

export const errorHandler = (
  err: Error | AppError,
  req: Request,
  res: Response,
  next: NextFunction
) => {
  if (err instanceof AppError) {
    // 操作错误，返回给客户端
    logger.error(`[${req.method}] ${req.path} - ${err.message}`, {
      statusCode: err.statusCode,
      stack: err.stack,
    });

    return res.status(err.statusCode).json({
      success: false,
      error: err.message,
    });
  }

  // 未知错误，记录详细信息
  logger.error(`[${req.method}] ${req.path} - 未处理的错误`, {
    error: err.message,
    stack: err.stack,
  });

  // 生产环境不暴露错误详情
  const message =
    process.env.NODE_ENV === 'production'
      ? '服务器内部错误'
      : err.message;

  return res.status(500).json({
    success: false,
    error: message,
  });
};

// 异步错误处理包装器
export const asyncHandler = (
  fn: (req: Request, res: Response, next: NextFunction) => Promise<any>
) => {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};
