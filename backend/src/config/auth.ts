import { SignOptions, Algorithm } from 'jsonwebtoken';
import { logger } from '../utils/logger';

/**
 * JWT 统一配置
 * 解决之前各处使用不同默认值的问题
 */

const JWT_ALGORITHM: Algorithm = 'HS256';
const JWT_MIN_SECRET_LENGTH = 16;

/**
 * 获取JWT密钥
 * 在生产环境强制要求配置，开发环境允许使用默认值（但会警告）
 */
export function getJwtSecret(): string {
  const secret = process.env.JWT_SECRET;
  const isProduction = process.env.NODE_ENV === 'production';

  if (!secret) {
    if (isProduction) {
      throw new Error('生产环境必须配置 JWT_SECRET 环境变量');
    }
    // 开发环境使用默认值，但发出警告
    logger.warn('警告: JWT_SECRET 未配置，使用开发环境默认值。请勿在生产环境使用！');
    return 'fm-deploy-dev-secret-key-2024';
  }

  if (secret.length < JWT_MIN_SECRET_LENGTH) {
    throw new Error(`JWT_SECRET 长度不足，需要至少 ${JWT_MIN_SECRET_LENGTH} 个字符`);
  }

  return secret;
}

/**
 * JWT 签名选项
 */
export const JWT_SIGN_OPTIONS: SignOptions = {
  algorithm: JWT_ALGORITHM,
  expiresIn: (process.env.JWT_EXPIRES_IN || '7d') as SignOptions['expiresIn'],
  issuer: 'fm-deploy',
};

/**
 * JWT 验证选项
 */
export const JWT_VERIFY_OPTIONS = {
  algorithms: [JWT_ALGORITHM] as Algorithm[],
  issuer: 'fm-deploy',
};

/**
 * JWT Payload 类型定义
 */
export interface JwtPayload {
  id: number;
  username: string;
  role: 'admin' | 'developer';
  iat?: number;
  exp?: number;
  iss?: string;
}

/**
 * 验证 JWT Payload 结构是否有效
 */
export function isValidJwtPayload(payload: unknown): payload is JwtPayload {
  if (typeof payload !== 'object' || payload === null) {
    return false;
  }

  const p = payload as Record<string, unknown>;
  return (
    typeof p.id === 'number' &&
    typeof p.username === 'string' &&
    (p.role === 'admin' || p.role === 'developer')
  );
}
