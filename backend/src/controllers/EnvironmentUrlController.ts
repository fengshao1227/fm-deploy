import { Response } from 'express';
import { AppDataSource } from '../config/database';
import { EnvironmentUrl } from '../models/EnvironmentUrl';
import { AppError, asyncHandler } from '../middlewares/errorHandler';
import { AuthRequest } from '../middlewares/auth';

export class EnvironmentUrlController {
  /**
   * 获取环境URL列表
   * GET /api/environment-urls
   * Query: { keyword?, page?, pageSize? }
   */
  static list = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { keyword, page = 1, pageSize = 20 } = req.query;
    const envUrlRepo = AppDataSource.getRepository(EnvironmentUrl);

    const queryBuilder = envUrlRepo.createQueryBuilder('envUrl');

    // 关键字搜索
    if (keyword) {
      queryBuilder.andWhere(
        '(envUrl.name LIKE :keyword OR envUrl.url LIKE :keyword OR envUrl.description LIKE :keyword)',
        { keyword: `%${keyword}%` }
      );
    }

    // 分页
    const skip = (Number(page) - 1) * Number(pageSize);
    queryBuilder.skip(skip).take(Number(pageSize));

    // 排序：按使用次数降序，最后使用时间降序
    queryBuilder.orderBy('envUrl.usageCount', 'DESC')
                .addOrderBy('envUrl.lastUsedAt', 'DESC')
                .addOrderBy('envUrl.createdAt', 'DESC');

    const [envUrls, total] = await queryBuilder.getManyAndCount();

    res.json({
      success: true,
      data: {
        list: envUrls,
        pagination: {
          page: Number(page),
          pageSize: Number(pageSize),
          total,
          totalPages: Math.ceil(total / Number(pageSize)),
        },
      },
    });
  });

  /**
   * 获取所有环境URL（简单列表，用于下拉选择）
   * GET /api/environment-urls/all
   */
  static getAll = asyncHandler(async (req: AuthRequest, res: Response) => {
    const envUrlRepo = AppDataSource.getRepository(EnvironmentUrl);

    const envUrls = await envUrlRepo.find({
      select: ['id', 'name', 'url', 'usageCount', 'lastUsedAt', 'createdAt'],
      order: {
        usageCount: 'DESC',
        lastUsedAt: 'DESC'
      },
    });

    res.json({
      success: true,
      data: envUrls,
    });
  });

  /**
   * 获取单个环境URL详情
   * GET /api/environment-urls/:id
   */
  static getById = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const envUrlRepo = AppDataSource.getRepository(EnvironmentUrl);

    const envUrl = await envUrlRepo.findOne({
      where: { id: Number(id) },
    });

    if (!envUrl) {
      throw new AppError('环境URL不存在', 404);
    }

    res.json({
      success: true,
      data: envUrl,
    });
  });

  /**
   * 创建环境URL
   * POST /api/environment-urls
   * Body: { name, url, description? }
   */
  static create = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { name, url, description } = req.body;

    // 验证必填字段
    if (!name || !url) {
      throw new AppError('环境名称和URL为必填项', 400);
    }

    // 验证URL格式
    try {
      new URL(url);
    } catch {
      throw new AppError('URL格式不正确', 400);
    }

    const envUrlRepo = AppDataSource.getRepository(EnvironmentUrl);

    // 检查URL是否已存在
    const existingUrl = await envUrlRepo.findOne({
      where: { url },
    });

    if (existingUrl) {
      throw new AppError('该URL已存在', 400);
    }

    // 创建环境URL
    const envUrl = envUrlRepo.create({
      name,
      url,
      description: description || null,
      usageCount: 0,
    });

    await envUrlRepo.save(envUrl);

    res.status(201).json({
      success: true,
      data: envUrl,
      message: '环境URL创建成功',
    });
  });

  /**
   * 更新环境URL
   * PUT /api/environment-urls/:id
   * Body: { name?, url?, description? }
   */
  static update = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const { name, url, description } = req.body;

    const envUrlRepo = AppDataSource.getRepository(EnvironmentUrl);
    const envUrl = await envUrlRepo.findOne({ where: { id: Number(id) } });

    if (!envUrl) {
      throw new AppError('环境URL不存在', 404);
    }

    // 如果要更新URL，检查新URL是否已被其他记录使用
    if (url && url !== envUrl.url) {
      // 验证URL格式
      try {
        new URL(url);
      } catch {
        throw new AppError('URL格式不正确', 400);
      }

      const existingUrl = await envUrlRepo.findOne({
        where: { url },
      });

      if (existingUrl && existingUrl.id !== envUrl.id) {
        throw new AppError('该URL已被其他环境使用', 400);
      }
    }

    // 更新字段
    if (name !== undefined) {
      envUrl.name = name;
    }
    if (url !== undefined) {
      envUrl.url = url;
    }
    if (description !== undefined) {
      envUrl.description = description;
    }

    await envUrlRepo.save(envUrl);

    res.json({
      success: true,
      data: envUrl,
      message: '环境URL更新成功',
    });
  });

  /**
   * 删除环境URL
   * DELETE /api/environment-urls/:id
   */
  static delete = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const envUrlRepo = AppDataSource.getRepository(EnvironmentUrl);

    const envUrl = await envUrlRepo.findOne({ where: { id: Number(id) } });

    if (!envUrl) {
      throw new AppError('环境URL不存在', 404);
    }

    // 检查是否有使用记录（可选）
    if (envUrl.usageCount > 0) {
      // 可以允许删除使用过的URL，但给出提示
      console.warn(`删除的环境URL "${envUrl.name}" 曾被使用 ${envUrl.usageCount} 次`);
    }

    await envUrlRepo.remove(envUrl);

    res.json({
      success: true,
      message: '环境URL删除成功',
    });
  });

  /**
   * 增加URL使用次数
   * POST /api/environment-urls/:id/use
   * 这个接口会在部署时自动调用，用于记录URL的使用情况
   */
  static incrementUsage = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const envUrlRepo = AppDataSource.getRepository(EnvironmentUrl);

    const envUrl = await envUrlRepo.findOne({ where: { id: Number(id) } });

    if (!envUrl) {
      throw new AppError('环境URL不存在', 404);
    }

    // 增加使用次数
    envUrl.usageCount += 1;
    envUrl.lastUsedAt = new Date();

    await envUrlRepo.save(envUrl);

    res.json({
      success: true,
      data: {
        id: envUrl.id,
        usageCount: envUrl.usageCount,
        lastUsedAt: envUrl.lastUsedAt,
      },
      message: '使用次数已更新',
    });
  });

  /**
   * 根据URL查找或创建记录
   * POST /api/environment-urls/find-or-create
   * Body: { url, name?, description? }
   * 在部署时，如果用户直接输入了新的URL，可以使用这个接口自动创建记录
   */
  static findOrCreate = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { url, name, description } = req.body;

    if (!url) {
      throw new AppError('URL为必填项', 400);
    }

    // 验证URL格式
    try {
      new URL(url);
    } catch {
      throw new AppError('URL格式不正确', 400);
    }

    const envUrlRepo = AppDataSource.getRepository(EnvironmentUrl);

    // 先查找是否已存在
    let envUrl = await envUrlRepo.findOne({
      where: { url },
    });

    if (envUrl) {
      // 如果存在，更新使用次数
      envUrl.usageCount += 1;
      envUrl.lastUsedAt = new Date();
      if (name && !envUrl.name) {
        envUrl.name = name;
      }
      if (description) {
        envUrl.description = description;
      }
    } else {
      // 如果不存在，创建新记录
      envUrl = envUrlRepo.create({
        name: name || `环境 ${new Date().toLocaleDateString()}`,
        url,
        description: description || null,
        usageCount: 1,
        lastUsedAt: new Date(),
      });
    }

    await envUrlRepo.save(envUrl);

    res.json({
      success: true,
      data: envUrl,
      message: envUrl.usageCount === 1 ? '新的环境URL已创建' : '使用次数已更新',
    });
  });
}