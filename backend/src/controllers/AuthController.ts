import { Response } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { AppDataSource } from '../config/database';
import { User } from '../models/User';
import { AppError, asyncHandler } from '../middlewares/errorHandler';
import { AuthRequest } from '../middlewares/auth';
import { getJwtSecret, JWT_SIGN_OPTIONS } from '../config/auth';

export class AuthController {
  /**
   * 用户登录
   * POST /api/auth/login
   * Body: { username, password }
   */
  static login = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { username, password } = req.body;

    // 验证输入
    if (!username || !password) {
      throw new AppError('用户名和密码不能为空', 400);
    }

    // 查找用户
    const userRepo = AppDataSource.getRepository(User);
    const user = await userRepo.findOne({ where: { username } });

    if (!user) {
      throw new AppError('用户名或密码错误', 401);
    }

    // 验证密码
    const isValidPassword = await bcrypt.compare(password, user.passwordHash);
    if (!isValidPassword) {
      throw new AppError('用户名或密码错误', 401);
    }

    // 生成JWT token (使用统一配置)
    const token = jwt.sign(
      {
        id: user.id,
        username: user.username,
        role: user.role,
      },
      getJwtSecret(),
      JWT_SIGN_OPTIONS
    );

    // 返回结果
    res.json({
      success: true,
      data: {
        token,
        user: {
          id: user.id,
          username: user.username,
          name: user.name,
          role: user.role,
        },
      },
    });
  });

  /**
   * 获取当前登录用户信息
   * GET /api/auth/me
   * Headers: Authorization: Bearer <token>
   */
  static me = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.user) {
      throw new AppError('未认证', 401);
    }

    const userRepo = AppDataSource.getRepository(User);
    const user = await userRepo.findOne({ where: { id: req.user.id } });

    if (!user) {
      throw new AppError('用户不存在', 404);
    }

    res.json({
      success: true,
      data: {
        id: user.id,
        username: user.username,
        name: user.name,
        role: user.role,
        createdAt: user.createdAt,
      },
    });
  });

  /**
   * 修改密码
   * POST /api/auth/change-password
   * Body: { oldPassword, newPassword }
   */
  static changePassword = asyncHandler(
    async (req: AuthRequest, res: Response) => {
      const { oldPassword, newPassword } = req.body;

      if (!oldPassword || !newPassword) {
        throw new AppError('旧密码和新密码不能为空', 400);
      }

      if (newPassword.length < 6) {
        throw new AppError('新密码长度不能少于6位', 400);
      }

      const userRepo = AppDataSource.getRepository(User);
      const user = await userRepo.findOne({ where: { id: req.user!.id } });

      if (!user) {
        throw new AppError('用户不存在', 404);
      }

      // 验证旧密码
      const isValidPassword = await bcrypt.compare(
        oldPassword,
        user.passwordHash
      );
      if (!isValidPassword) {
        throw new AppError('旧密码错误', 401);
      }

      // 生成新密码哈希
      const salt = await bcrypt.genSalt(10);
      user.passwordHash = await bcrypt.hash(newPassword, salt);

      await userRepo.save(user);

      res.json({
        success: true,
        message: '密码修改成功',
      });
    }
  );
}
