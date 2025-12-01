import { Response } from 'express';
import { AppDataSource } from '../config/database';
import { Deployment } from '../models/Deployment';
import { DeploymentLog } from '../models/DeploymentLog';
import { ProjectEnvironment } from '../models/ProjectEnvironment';
import { AppError, asyncHandler } from '../middlewares/errorHandler';
import { AuthRequest } from '../middlewares/auth';
import { createDeploymentService, DeploymentService } from '../services/DeploymentService';
import { logger } from '../utils/logger';

// 存储正在执行的部署服务实例（用于WebSocket通信）
const runningDeployments = new Map<number, DeploymentService>();

export class DeploymentController {
  /**
   * 获取部署记录列表
   * GET /api/deployments
   * Query: { projectEnvironmentId?, status?, page?, pageSize? }
   */
  static list = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { projectEnvironmentId, status, page = 1, pageSize = 10 } = req.query;
    const deploymentRepo = AppDataSource.getRepository(Deployment);

    const queryBuilder = deploymentRepo
      .createQueryBuilder('deployment')
      .leftJoinAndSelect('deployment.projectEnvironment', 'projectEnvironment')
      .leftJoinAndSelect('projectEnvironment.project', 'project')
      .leftJoinAndSelect('projectEnvironment.environment', 'environment')
      .leftJoinAndSelect('deployment.user', 'user');

    // 按项目环境过滤
    if (projectEnvironmentId) {
      queryBuilder.andWhere('deployment.projectEnvironmentId = :projectEnvironmentId', {
        projectEnvironmentId: Number(projectEnvironmentId),
      });
    }

    // 按状态过滤
    if (status) {
      queryBuilder.andWhere('deployment.status = :status', { status });
    }

    // 分页
    const skip = (Number(page) - 1) * Number(pageSize);
    queryBuilder.skip(skip).take(Number(pageSize));

    // 排序
    queryBuilder.orderBy('deployment.createdAt', 'DESC');

    const [deployments, total] = await queryBuilder.getManyAndCount();

    // 格式化返回数据
    const list = deployments.map((d) => ({
      id: d.id,
      status: d.status,
      commitHash: d.commitHash,
      commitMessage: d.commitMessage,
      startedAt: d.startedAt,
      finishedAt: d.finishedAt,
      createdAt: d.createdAt,
      project: d.projectEnvironment?.project
        ? {
            id: d.projectEnvironment.project.id,
            name: d.projectEnvironment.project.name,
            projectKey: d.projectEnvironment.project.projectKey,
          }
        : null,
      environment: d.projectEnvironment?.environment
        ? {
            id: d.projectEnvironment.environment.id,
            name: d.projectEnvironment.environment.name,
          }
        : null,
      user: d.user
        ? {
            id: d.user.id,
            username: d.user.username,
            name: d.user.name,
          }
        : null,
    }));

    res.json({
      success: true,
      data: {
        list,
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
   * 获取部署详情
   * GET /api/deployments/:id
   */
  static getById = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const deploymentRepo = AppDataSource.getRepository(Deployment);

    const deployment = await deploymentRepo.findOne({
      where: { id: Number(id) },
      relations: [
        'projectEnvironment',
        'projectEnvironment.project',
        'projectEnvironment.environment',
        'user',
      ],
    });

    if (!deployment) {
      throw new AppError('部署记录不存在', 404);
    }

    res.json({
      success: true,
      data: {
        id: deployment.id,
        status: deployment.status,
        commitHash: deployment.commitHash,
        commitMessage: deployment.commitMessage,
        startedAt: deployment.startedAt,
        finishedAt: deployment.finishedAt,
        errorMessage: deployment.errorMessage,
        createdAt: deployment.createdAt,
        projectEnvironment: {
          id: deployment.projectEnvironment.id,
          deployPath: deployment.projectEnvironment.deployPath,
          branch: deployment.projectEnvironment.branch,
          project: {
            id: deployment.projectEnvironment.project.id,
            name: deployment.projectEnvironment.project.name,
            projectKey: deployment.projectEnvironment.project.projectKey,
            type: deployment.projectEnvironment.project.type,
          },
          environment: {
            id: deployment.projectEnvironment.environment.id,
            name: deployment.projectEnvironment.environment.name,
            sshHost: deployment.projectEnvironment.environment.sshHost,
          },
        },
        user: {
          id: deployment.user.id,
          username: deployment.user.username,
          name: deployment.user.name,
        },
      },
    });
  });

  /**
   * 创建部署任务
   * POST /api/deployments
   * Body: { projectEnvironmentId }
   */
  static create = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { projectEnvironmentId } = req.body;

    if (!projectEnvironmentId) {
      throw new AppError('项目环境配置ID为必填项', 400);
    }

    // 验证项目环境配置是否存在
    const projEnvRepo = AppDataSource.getRepository(ProjectEnvironment);
    const projectEnvironment = await projEnvRepo.findOne({
      where: { id: Number(projectEnvironmentId) },
      relations: ['project', 'environment'],
    });

    if (!projectEnvironment) {
      throw new AppError('项目环境配置不存在', 404);
    }

    if (!projectEnvironment.enabled) {
      throw new AppError('该项目环境配置已禁用', 400);
    }

    // 创建部署服务
    const deploymentService = createDeploymentService();

    // 创建部署任务
    const deployment = await deploymentService.createDeployment({
      projectEnvironmentId: Number(projectEnvironmentId),
      userId: req.user!.id,
    });

    // 存储部署服务实例
    runningDeployments.set(deployment.id, deploymentService);

    // 异步执行部署（不等待完成）
    deploymentService.execute()
      .catch((error) => {
        // 捕获并记录异步执行中的未处理错误
        logger.error(`部署 ${deployment.id} 执行异常:`, error);
      })
      .finally(() => {
        // 部署完成后移除实例
        runningDeployments.delete(deployment.id);
      });

    res.status(201).json({
      success: true,
      data: {
        id: deployment.id,
        status: deployment.status,
        project: {
          id: projectEnvironment.project.id,
          name: projectEnvironment.project.name,
        },
        environment: {
          id: projectEnvironment.environment.id,
          name: projectEnvironment.environment.name,
        },
      },
      message: '部署任务已创建',
    });
  });

  /**
   * 获取部署日志
   * GET /api/deployments/:id/logs
   * Query: { page?, pageSize?, logType? }
   */
  static getLogs = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const { page = 1, pageSize = 100, logType } = req.query;
    const deploymentRepo = AppDataSource.getRepository(Deployment);

    // 验证部署记录存在
    const deployment = await deploymentRepo.findOne({
      where: { id: Number(id) },
    });

    if (!deployment) {
      throw new AppError('部署记录不存在', 404);
    }

    // 获取日志（支持分页）
    const { logs, total } = await DeploymentService.getLogs(Number(id), {
      page: Number(page),
      pageSize: Number(pageSize),
      logType: logType as string | undefined,
    });

    res.json({
      success: true,
      data: {
        deploymentId: Number(id),
        status: deployment.status,
        logs: logs.map((log) => ({
          id: log.id,
          logType: log.logType,
          message: log.message,
          timestamp: log.timestamp,
        })),
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
   * 回滚部署
   * POST /api/deployments/:id/rollback
   */
  static rollback = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const deploymentRepo = AppDataSource.getRepository(Deployment);

    // 验证原部署记录存在
    const originalDeployment = await deploymentRepo.findOne({
      where: { id: Number(id) },
      relations: ['projectEnvironment', 'projectEnvironment.project', 'projectEnvironment.environment'],
    });

    if (!originalDeployment) {
      throw new AppError('部署记录不存在', 404);
    }

    if (originalDeployment.status !== 'success') {
      throw new AppError('只能回滚成功的部署', 400);
    }

    // 创建部署服务并执行回滚
    const deploymentService = createDeploymentService();

    // 回滚操作是同步等待完成的，因此完成后无需存储到runningDeployments
    // 如需支持WebSocket实时推送回滚日志，可重构为异步模式
    try {
      const rollbackDeployment = await deploymentService.rollback(Number(id));

      res.status(201).json({
        success: true,
        data: {
          id: rollbackDeployment.id,
          status: rollbackDeployment.status,
          originalDeploymentId: Number(id),
        },
        message: '回滚任务已完成',
      });
    } catch (error) {
      logger.error(`回滚部署 ${id} 执行异常:`, error);
      throw error;
    }
  });

  /**
   * 取消部署
   * POST /api/deployments/:id/cancel
   */
  static cancel = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const deploymentRepo = AppDataSource.getRepository(Deployment);

    const deployment = await deploymentRepo.findOne({
      where: { id: Number(id) },
    });

    if (!deployment) {
      throw new AppError('部署记录不存在', 404);
    }

    if (deployment.status !== 'pending' && deployment.status !== 'running') {
      throw new AppError('只能取消待执行或执行中的部署', 400);
    }

    // 获取正在运行的部署服务
    const deploymentService = runningDeployments.get(Number(id));
    if (deploymentService) {
      await deploymentService.cancel(Number(id));
      runningDeployments.delete(Number(id));
    } else {
      // 直接更新数据库状态
      deployment.status = 'failed';
      deployment.finishedAt = new Date();
      deployment.errorMessage = '用户取消部署';
      await deploymentRepo.save(deployment);
    }

    res.json({
      success: true,
      message: '部署已取消',
    });
  });

  /**
   * 获取项目环境的可回滚版本列表
   * GET /api/project-environments/:id/versions
   */
  static getVersions = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const projEnvRepo = AppDataSource.getRepository(ProjectEnvironment);

    // 验证项目环境配置存在
    const projectEnvironment = await projEnvRepo.findOne({
      where: { id: Number(id) },
    });

    if (!projectEnvironment) {
      throw new AppError('项目环境配置不存在', 404);
    }

    // 获取备份版本列表
    const versions = await DeploymentService.getBackupVersions(Number(id));

    res.json({
      success: true,
      data: {
        projectEnvironmentId: Number(id),
        versions: versions.map((v) => ({
          id: v.id,
          name: v.backupName,
          path: v.backupPath,
          createdAt: v.createdAt,
          deploymentId: v.deploymentId,
        })),
      },
    });
  });

  /**
   * 回滚到指定备份版本
   * POST /api/snapshots/:snapshotId/rollback
   */
  static rollbackToVersion = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { snapshotId } = req.params;

    // 创建部署服务并执行回滚
    const deploymentService = createDeploymentService();

    try {
      const rollbackDeployment = await deploymentService.rollbackToBackup(
        Number(snapshotId),
        req.user!.id
      );

      res.status(201).json({
        success: true,
        data: {
          id: rollbackDeployment.id,
          status: rollbackDeployment.status,
          snapshotId: Number(snapshotId),
        },
        message: '回滚任务已完成',
      });
    } catch (error) {
      logger.error(`回滚到版本 ${snapshotId} 执行异常:`, error);
      throw error;
    }
  });

  /**
   * 获取项目的最近部署记录
   * GET /api/projects/:projectId/deployments
   */
  static listByProject = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { projectId } = req.params;
    const { page = 1, pageSize = 10 } = req.query;

    const deploymentRepo = AppDataSource.getRepository(Deployment);

    const queryBuilder = deploymentRepo
      .createQueryBuilder('deployment')
      .leftJoinAndSelect('deployment.projectEnvironment', 'projectEnvironment')
      .leftJoinAndSelect('projectEnvironment.environment', 'environment')
      .leftJoinAndSelect('deployment.user', 'user')
      .where('projectEnvironment.projectId = :projectId', { projectId: Number(projectId) });

    // 分页
    const skip = (Number(page) - 1) * Number(pageSize);
    queryBuilder.skip(skip).take(Number(pageSize));

    // 排序
    queryBuilder.orderBy('deployment.createdAt', 'DESC');

    const [deployments, total] = await queryBuilder.getManyAndCount();

    const list = deployments.map((d) => ({
      id: d.id,
      status: d.status,
      commitHash: d.commitHash,
      commitMessage: d.commitMessage,
      startedAt: d.startedAt,
      finishedAt: d.finishedAt,
      createdAt: d.createdAt,
      environment: d.projectEnvironment?.environment
        ? {
            id: d.projectEnvironment.environment.id,
            name: d.projectEnvironment.environment.name,
          }
        : null,
      user: d.user
        ? {
            id: d.user.id,
            username: d.user.username,
            name: d.user.name,
          }
        : null,
    }));

    res.json({
      success: true,
      data: {
        list,
        pagination: {
          page: Number(page),
          pageSize: Number(pageSize),
          total,
          totalPages: Math.ceil(total / Number(pageSize)),
        },
      },
    });
  });
}

// 导出运行中的部署服务（供WebSocket使用）
export { runningDeployments };
