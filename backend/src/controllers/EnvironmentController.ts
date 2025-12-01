import { Response } from 'express';
import { AppDataSource } from '../config/database';
import { Environment } from '../models/Environment';
import { ProjectEnvironment } from '../models/ProjectEnvironment';
import { Deployment } from '../models/Deployment';
import { DeploymentLog } from '../models/DeploymentLog';
import { DeploymentSnapshot } from '../models/DeploymentSnapshot';
import { AppError, asyncHandler } from '../middlewares/errorHandler';
import { AuthRequest } from '../middlewares/auth';
import { createSSHService } from '../services/SSHService';

export class EnvironmentController {
  /**
   * 获取环境列表
   * GET /api/environments
   * Query: { keyword?, page?, pageSize? }
   */
  static list = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { keyword, page = 1, pageSize = 10 } = req.query;
    const envRepo = AppDataSource.getRepository(Environment);

    const queryBuilder = envRepo.createQueryBuilder('env');

    // 关键字搜索
    if (keyword) {
      queryBuilder.andWhere(
        '(env.name LIKE :keyword OR env.sshHost LIKE :keyword)',
        { keyword: `%${keyword}%` }
      );
    }

    // 分页
    const skip = (Number(page) - 1) * Number(pageSize);
    queryBuilder.skip(skip).take(Number(pageSize));

    // 排序
    queryBuilder.orderBy('env.createdAt', 'DESC');

    const [environments, total] = await queryBuilder.getManyAndCount();

    // 隐藏敏感信息
    const safeEnvironments = environments.map((env) => ({
      ...env,
      sshKeyPath: env.sshKeyPath ? '******' : null,
    }));

    res.json({
      success: true,
      data: {
        list: safeEnvironments,
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
   * 获取所有环境（简单列表，用于下拉选择）
   * GET /api/environments/all
   */
  static getAll = asyncHandler(async (req: AuthRequest, res: Response) => {
    const envRepo = AppDataSource.getRepository(Environment);

    const environments = await envRepo.find({
      select: ['id', 'name', 'sshHost', 'sshPort', 'sshUser'],
      order: { name: 'ASC' },
    });

    res.json({
      success: true,
      data: environments,
    });
  });

  /**
   * 获取单个环境详情
   * GET /api/environments/:id
   */
  static getById = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const envRepo = AppDataSource.getRepository(Environment);

    const environment = await envRepo.findOne({
      where: { id: Number(id) },
      relations: ['projectEnvironments', 'projectEnvironments.project'],
    });

    if (!environment) {
      throw new AppError('环境不存在', 404);
    }

    // 隐藏敏感信息（仅管理员可见完整信息）
    const isAdmin = req.user?.role === 'admin';
    const safeEnvironment = {
      ...environment,
      sshKeyPath: isAdmin ? environment.sshKeyPath : '******',
    };

    res.json({
      success: true,
      data: safeEnvironment,
    });
  });

  /**
   * 创建环境
   * POST /api/environments
   * Body: { name, sshHost, sshPort?, sshUser, sshKeyPath, description? }
   */
  static create = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { name, sshHost, sshPort = 22, sshUser, sshKeyPath, description } =
      req.body;

    // 验证必填字段
    if (!name || !sshHost || !sshUser || !sshKeyPath) {
      throw new AppError('环境名称、SSH主机、SSH用户和密钥路径为必填项', 400);
    }

    // 验证SSH端口
    if (sshPort < 1 || sshPort > 65535) {
      throw new AppError('SSH端口必须在1-65535之间', 400);
    }

    const envRepo = AppDataSource.getRepository(Environment);

    // 检查环境名称是否已存在
    const existingEnv = await envRepo.findOne({ where: { name } });
    if (existingEnv) {
      throw new AppError('环境名称已存在', 400);
    }

    // 创建环境
    const environment = envRepo.create({
      name,
      sshHost,
      sshPort,
      sshUser,
      sshKeyPath,
      description: description || null,
    });

    await envRepo.save(environment);

    res.status(201).json({
      success: true,
      data: {
        ...environment,
        sshKeyPath: '******',
      },
      message: '环境创建成功',
    });
  });

  /**
   * 更新环境
   * PUT /api/environments/:id
   * Body: { name?, sshHost?, sshPort?, sshUser?, sshKeyPath?, description? }
   */
  static update = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const { name, sshHost, sshPort, sshUser, sshKeyPath, description } =
      req.body;

    const envRepo = AppDataSource.getRepository(Environment);
    const environment = await envRepo.findOne({ where: { id: Number(id) } });

    if (!environment) {
      throw new AppError('环境不存在', 404);
    }

    // 如果修改名称，检查是否重复
    if (name && name !== environment.name) {
      const existingEnv = await envRepo.findOne({ where: { name } });
      if (existingEnv) {
        throw new AppError('环境名称已存在', 400);
      }
      environment.name = name;
    }

    // 更新其他字段
    if (sshHost !== undefined) {
      environment.sshHost = sshHost;
    }
    if (sshPort !== undefined) {
      if (sshPort < 1 || sshPort > 65535) {
        throw new AppError('SSH端口必须在1-65535之间', 400);
      }
      environment.sshPort = sshPort;
    }
    if (sshUser !== undefined) {
      environment.sshUser = sshUser;
    }
    if (sshKeyPath !== undefined) {
      environment.sshKeyPath = sshKeyPath;
    }
    if (description !== undefined) {
      environment.description = description;
    }

    await envRepo.save(environment);

    res.json({
      success: true,
      data: {
        ...environment,
        sshKeyPath: '******',
      },
      message: '环境更新成功',
    });
  });

  /**
   * 删除环境
   * DELETE /api/environments/:id
   * 级联删除：自动删除关联的项目环境配置及部署记录
   */
  static delete = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const envRepo = AppDataSource.getRepository(Environment);

    const environment = await envRepo.findOne({
      where: { id: Number(id) },
      relations: ['projectEnvironments'],
    });

    if (!environment) {
      throw new AppError('环境不存在', 404);
    }

    // 级联删除：删除关联的项目环境配置及其部署记录
    if (
      environment.projectEnvironments &&
      environment.projectEnvironments.length > 0
    ) {
      const projEnvIds = environment.projectEnvironments.map((pe) => pe.id);

      // 获取所有关联的部署记录
      const deploymentRepo = AppDataSource.getRepository(Deployment);
      const deployments = await deploymentRepo.find({
        where: projEnvIds.map((peId) => ({ projectEnvironmentId: peId })),
      });

      if (deployments.length > 0) {
        const deploymentIds = deployments.map((d) => d.id);

        // 删除部署日志
        const logRepo = AppDataSource.getRepository(DeploymentLog);
        await logRepo
          .createQueryBuilder()
          .delete()
          .where('deployment_id IN (:...ids)', { ids: deploymentIds })
          .execute();

        // 删除部署快照
        const snapshotRepo = AppDataSource.getRepository(DeploymentSnapshot);
        await snapshotRepo
          .createQueryBuilder()
          .delete()
          .where('deployment_id IN (:...ids)', { ids: deploymentIds })
          .execute();

        // 删除部署记录
        await deploymentRepo.remove(deployments);
      }

      // 删除项目环境配置
      const projEnvRepo = AppDataSource.getRepository(ProjectEnvironment);
      await projEnvRepo.remove(environment.projectEnvironments);
    }

    await envRepo.remove(environment);

    res.json({
      success: true,
      message: '环境及关联配置删除成功',
    });
  });

  /**
   * 测试SSH连接
   * POST /api/environments/:id/test
   */
  static testConnection = asyncHandler(
    async (req: AuthRequest, res: Response) => {
      const { id } = req.params;
      const envRepo = AppDataSource.getRepository(Environment);

      const environment = await envRepo.findOne({ where: { id: Number(id) } });

      if (!environment) {
        throw new AppError('环境不存在', 404);
      }

      // 创建SSH服务实例进行连接测试
      const sshService = createSSHService({
        host: environment.sshHost,
        port: environment.sshPort,
        username: environment.sshUser,
        privateKeyPath: environment.sshKeyPath,
      });

      const result = await sshService.testConnection();

      res.json({
        success: true,
        data: {
          connected: result.success,
          message: result.message,
          environment: {
            name: environment.name,
            host: environment.sshHost,
            port: environment.sshPort,
            user: environment.sshUser,
          },
          serverInfo: result.serverInfo,
        },
      });
    }
  );
}
