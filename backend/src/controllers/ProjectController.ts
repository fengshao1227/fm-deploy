import { Response } from 'express';
import { AppDataSource } from '../config/database';
import { Project } from '../models/Project';
import { ProjectEnvironment } from '../models/ProjectEnvironment';
import { Deployment } from '../models/Deployment';
import { DeploymentLog } from '../models/DeploymentLog';
import { DeploymentSnapshot } from '../models/DeploymentSnapshot';
import { AppError, asyncHandler } from '../middlewares/errorHandler';
import { AuthRequest } from '../middlewares/auth';
import { Like } from 'typeorm';

export class ProjectController {
  /**
   * 获取项目列表
   * GET /api/projects
   * Query: { keyword?, type?, page?, pageSize? }
   */
  static list = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { keyword, type, page = 1, pageSize = 10 } = req.query;
    const projectRepo = AppDataSource.getRepository(Project);

    const queryBuilder = projectRepo.createQueryBuilder('project');

    // 关键字搜索
    if (keyword) {
      queryBuilder.andWhere(
        '(project.name LIKE :keyword OR project.projectKey LIKE :keyword)',
        { keyword: `%${keyword}%` }
      );
    }

    // 类型过滤
    if (type && (type === 'frontend' || type === 'backend')) {
      queryBuilder.andWhere('project.type = :type', { type });
    }

    // 分页
    const skip = (Number(page) - 1) * Number(pageSize);
    queryBuilder.skip(skip).take(Number(pageSize));

    // 排序
    queryBuilder.orderBy('project.createdAt', 'DESC');

    const [projects, total] = await queryBuilder.getManyAndCount();

    res.json({
      success: true,
      data: {
        list: projects,
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
   * 获取单个项目详情
   * GET /api/projects/:id
   */
  static getById = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const projectRepo = AppDataSource.getRepository(Project);

    const project = await projectRepo.findOne({
      where: { id: Number(id) },
      relations: ['projectEnvironments', 'projectEnvironments.environment'],
    });

    if (!project) {
      throw new AppError('项目不存在', 404);
    }

    res.json({
      success: true,
      data: project,
    });
  });

  /**
   * 创建项目
   * POST /api/projects
   * Body: { name, projectKey, type, gitRepo?, description? }
   */
  static create = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { name, projectKey, type, gitRepo, description } = req.body;

    // 验证必填字段
    if (!name || !projectKey || !type) {
      throw new AppError('项目名称、项目标识和类型为必填项', 400);
    }

    // 验证类型
    if (!['frontend', 'backend'].includes(type)) {
      throw new AppError('项目类型必须是 frontend 或 backend', 400);
    }

    // 验证项目标识格式（只允许字母、数字、下划线、中划线）
    if (!/^[a-zA-Z][a-zA-Z0-9_-]*$/.test(projectKey)) {
      throw new AppError('项目标识必须以字母开头，只能包含字母、数字、下划线和中划线', 400);
    }

    const projectRepo = AppDataSource.getRepository(Project);

    // 检查项目标识是否已存在
    const existingProject = await projectRepo.findOne({
      where: { projectKey },
    });

    if (existingProject) {
      throw new AppError('项目标识已存在', 400);
    }

    // 创建项目
    const project = projectRepo.create({
      name,
      projectKey,
      type,
      gitRepo: gitRepo || null,
      description: description || null,
    });

    await projectRepo.save(project);

    res.status(201).json({
      success: true,
      data: project,
      message: '项目创建成功',
    });
  });

  /**
   * 更新项目
   * PUT /api/projects/:id
   * Body: { name?, gitRepo?, description? }
   */
  static update = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const { name, gitRepo, description } = req.body;

    const projectRepo = AppDataSource.getRepository(Project);
    const project = await projectRepo.findOne({ where: { id: Number(id) } });

    if (!project) {
      throw new AppError('项目不存在', 404);
    }

    // 更新字段
    if (name !== undefined) {
      project.name = name;
    }
    if (gitRepo !== undefined) {
      project.gitRepo = gitRepo;
    }
    if (description !== undefined) {
      project.description = description;
    }

    await projectRepo.save(project);

    res.json({
      success: true,
      data: project,
      message: '项目更新成功',
    });
  });

  /**
   * 删除项目
   * DELETE /api/projects/:id
   * 级联删除：自动删除关联的项目环境配置及部署记录
   */
  static delete = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const projectRepo = AppDataSource.getRepository(Project);

    const project = await projectRepo.findOne({
      where: { id: Number(id) },
      relations: ['projectEnvironments'],
    });

    if (!project) {
      throw new AppError('项目不存在', 404);
    }

    // 级联删除：删除关联的项目环境配置及其部署记录
    if (project.projectEnvironments && project.projectEnvironments.length > 0) {
      const projEnvIds = project.projectEnvironments.map((pe) => pe.id);

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
      await projEnvRepo.remove(project.projectEnvironments);
    }

    await projectRepo.remove(project);

    res.json({
      success: true,
      message: '项目及关联配置删除成功',
    });
  });

  /**
   * 获取所有项目（简单列表，用于下拉选择）
   * GET /api/projects/all
   */
  static getAll = asyncHandler(async (req: AuthRequest, res: Response) => {
    const projectRepo = AppDataSource.getRepository(Project);

    const projects = await projectRepo.find({
      select: ['id', 'name', 'projectKey', 'type'],
      order: { name: 'ASC' },
    });

    res.json({
      success: true,
      data: projects,
    });
  });
}
