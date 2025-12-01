import { AppError } from '../middlewares/errorHandler';

/**
 * 输入校验工具
 * 用于防止命令注入和路径穿越攻击
 */

/**
 * 校验路径/分支名称（严格模式）
 * 仅允许：字母、数字、点、下划线、斜杠、连字符
 */
export function validatePath(input: string, fieldName: string): void {
  if (!input || typeof input !== 'string') {
    throw new AppError(`${fieldName} 不能为空`, 400);
  }

  // 路径/分支名只允许安全字符
  const safePathRegex = /^[a-zA-Z0-9._\\/\\-]+$/;
  if (!safePathRegex.test(input)) {
    throw new AppError(`${fieldName} 包含非法字符，只允许字母、数字、点、下划线、斜杠和连字符`, 400);
  }

  // 禁止路径穿越
  if (input.includes('..')) {
    throw new AppError(`${fieldName} 不允许包含 '..'`, 400);
  }

  // 长度限制
  if (input.length > 200) {
    throw new AppError(`${fieldName} 长度不能超过200个字符`, 400);
  }
}

/**
 * 危险命令模式黑名单
 */
const DANGEROUS_PATTERNS = [
  /\$\(/,           // 命令替换 $(...)
  /`/,              // 反引号命令替换
  /;\s*$/,          // 分号结尾（可能接新命令）
  /\|\s*$/,         // 管道结尾
  />\s*\/etc/,      // 重定向到系统目录
  />\s*\/root/,     // 重定向到root目录
  /rm\s+-rf\s+\//,  // 危险的rm命令
  /mkfs/,           // 格式化命令
  /dd\s+if=/,       // dd命令
  /chmod\s+777/,    // 危险权限
  /curl.*\|\s*(ba)?sh/,  // 下载并执行
  /wget.*\|\s*(ba)?sh/,  // 下载并执行
  /eval\s/,         // eval命令
  /base64\s+-d/,    // base64解码（可能用于绕过）
];

/**
 * 校验部署命令（宽松模式 + 黑名单）
 * 允许常见命令字符，但禁止危险模式
 */
export function validateCommand(input: string | null | undefined, fieldName: string): void {
  // 空值允许
  if (!input) {
    return;
  }

  if (typeof input !== 'string') {
    throw new AppError(`${fieldName} 必须是字符串`, 400);
  }

  // 长度限制
  if (input.length > 1000) {
    throw new AppError(`${fieldName} 长度不能超过1000个字符`, 400);
  }

  // 禁止多行命令
  if (/[\r\n]/.test(input)) {
    throw new AppError(`${fieldName} 不允许包含换行符`, 400);
  }

  // 禁止空字节
  if (/\x00/.test(input)) {
    throw new AppError(`${fieldName} 包含非法字符`, 400);
  }

  // 检查危险模式
  for (const pattern of DANGEROUS_PATTERNS) {
    if (pattern.test(input)) {
      throw new AppError(`${fieldName} 包含不允许的命令模式`, 400);
    }
  }
}

/**
 * 校验项目环境配置输入
 */
export function validateProjectEnvironmentInput(input: {
  deployPath?: string;
  branch?: string;
  buildCommand?: string | null;
  preDeployCommand?: string | null;
  postDeployCommand?: string | null;
}): void {
  if (input.deployPath !== undefined) {
    validatePath(input.deployPath, '部署路径');
  }

  if (input.branch !== undefined) {
    validatePath(input.branch, '分支名称');
  }

  validateCommand(input.buildCommand, '构建命令');
  validateCommand(input.preDeployCommand, '部署前命令');
  validateCommand(input.postDeployCommand, '部署后命令');
}
