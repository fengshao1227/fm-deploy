import 'reflect-metadata';
import bcrypt from 'bcrypt';
import dotenv from 'dotenv';
import { AppDataSource } from '../config/database';
import { User } from '../models/User';
import { logger } from '../utils/logger';

dotenv.config();

async function seed() {
  try {
    // 连接数据库
    logger.info('正在连接数据库...');
    await AppDataSource.initialize();
    logger.info('数据库连接成功');

    const userRepo = AppDataSource.getRepository(User);

    // 检查是否已存在管理员
    const existingAdmin = await userRepo.findOne({
      where: { username: 'admin' },
    });

    if (existingAdmin) {
      logger.info('管理员用户已存在，跳过创建');
    } else {
      // 创建管理员用户
      const salt = await bcrypt.genSalt(10);
      const passwordHash = await bcrypt.hash('admin123', salt);

      const admin = userRepo.create({
        username: 'admin',
        passwordHash,
        name: '系统管理员',
        role: 'admin',
      });

      await userRepo.save(admin);
      logger.info('✅ 管理员用户创建成功');
      logger.info('   用户名: admin');
      logger.info('   密码: admin123');
      logger.info('   ⚠️  请在首次登录后立即修改密码！');
    }

    // 创建测试开发者用户
    const existingDev = await userRepo.findOne({
      where: { username: 'developer' },
    });

    if (existingDev) {
      logger.info('开发者用户已存在，跳过创建');
    } else {
      const salt = await bcrypt.genSalt(10);
      const passwordHash = await bcrypt.hash('dev123', salt);

      const developer = userRepo.create({
        username: 'developer',
        passwordHash,
        name: '测试开发者',
        role: 'developer',
      });

      await userRepo.save(developer);
      logger.info('✅ 开发者用户创建成功');
      logger.info('   用户名: developer');
      logger.info('   密码: dev123');
    }

    logger.info('🎉 种子数据初始化完成！');

    await AppDataSource.destroy();
    process.exit(0);
  } catch (error) {
    logger.error('种子数据初始化失败:', error);
    process.exit(1);
  }
}

seed();
