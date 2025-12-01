import { Response } from 'express';
import { AppDataSource } from '../config/database';
import { ProjectEnvironment } from '../models/ProjectEnvironment';
import { Project } from '../models/Project';
import { Environment } from '../models/Environment';
import { AppError, asyncHandler } from '../middlewares/errorHandler';
import { AuthRequest } from '../middlewares/auth';
import { validateProjectEnvironmentInput } from '../utils/validation';

export class ProjectEnvironmentController {
  /**
   * 获取项目的环境配置列表
   * GET /api/projects/:projectId/environments
   */
  static listByProject = asyncHandler(
    async (req: AuthRequest, res: Response) => {
      const { projectId } = req.params;
      const projEnvRepo = AppDataSource.getRepository(ProjectEnvironment);

      // 验证项目是否存在
      const projectRepo = AppDataSource.getRepository(Project);
      const project = await projectRepo.findOne({
        where: { id: Number(projectId) },
      });

      if (!project) {
        throw new AppError('项目不存在', 404);
      }

      const projectEnvironments = await projEnvRepo.find({
        where: { projectId: Number(projectId) },
        relations: ['environment'],
        order: { createdAt: 'DESC' },
      });

      res.json({
        success: true,
        data: projectEnvironments,
      });
    }
  );

  /**
   * 获取单个项目环境配置详情
   * GET /api/project-environments/:id
   */
  static getById = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const projEnvRepo = AppDataSource.getRepository(ProjectEnvironment);

    const projectEnvironment = await projEnvRepo.findOne({
      where: { id: Number(id) },
      relations: ['project', 'environment'],
    });

    if (!projectEnvironment) {
      throw new AppError('项目环境配置不存在', 404);
    }

    res.json({
      success: true,
      data: projectEnvironment,
    });
  });

  /**
   * 为项目添加环境配置
   * POST /api/projects/:projectId/environments
   * Body: { environmentId, deployPath, branch?, deployMode?, buildOutputPath?, buildCommand?, preDeployCommand?, postDeployCommand? }
   */
  static create = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { projectId } = req.params;
    const {
      environmentId,
      deployPath,
      branch = 'master',
      deployMode = 'push',
      buildOutputPath = 'dist',
      buildCommand,
      preDeployCommand,
      postDeployCommand,
    } = req.body;

    // 验证必填字段
    if (!environmentId || !deployPath) {
      throw new AppError('环境ID和部署路径为必填项', 400);
    }

    // 输入安全校验（防止命令注入）
    validateProjectEnvironmentInput({
      deployPath,
      branch,
      buildCommand,
      preDeployCommand,
      postDeployCommand,
    });

    // 验证项目是否存在
    const projectRepo = AppDataSource.getRepository(Project);
    const project = await projectRepo.findOne({
      where: { id: Number(projectId) },
    });

    if (!project) {
      throw new AppError('项目不存在', 404);
    }

    // 验证环境是否存在
    const envRepo = AppDataSource.getRepository(Environment);
    const environment = await envRepo.findOne({
      where: { id: Number(environmentId) },
    });

    if (!environment) {
      throw new AppError('环境不存在', 404);
    }

    // 检查是否已存在该项目和环境的配置
    const projEnvRepo = AppDataSource.getRepository(ProjectEnvironment);
    const existingConfig = await projEnvRepo.findOne({
      where: {
        projectId: Number(projectId),
        environmentId: Number(environmentId),
      },
    });

    if (existingConfig) {
      throw new AppError('该项目在此环境下已有配置', 400);
    }

    // 验证 deployMode
    if (deployMode && !['push', 'pull'].includes(deployMode)) {
      throw new AppError('部署模式只能是 push 或 pull', 400);
    }

    // 创建项目环境配置
    const projectEnvironment = projEnvRepo.create({
      projectId: Number(projectId),
      environmentId: Number(environmentId),
      deployPath,
      branch,
      deployMode: deployMode || 'push',
      buildOutputPath: buildOutputPath || 'dist',
      buildCommand: buildCommand || null,
      preDeployCommand: preDeployCommand || null,
      postDeployCommand: postDeployCommand || null,
      enabled: true,
    });

    await projEnvRepo.save(projectEnvironment);

    // 返回完整数据
    const result = await projEnvRepo.findOne({
      where: { id: projectEnvironment.id },
      relations: ['project', 'environment'],
    });

    res.status(201).json({
      success: true,
      data: result,
      message: '项目环境配置创建成功',
    });
  });

  /**
   * 更新项目环境配置
   * PUT /api/project-environments/:id
   * Body: { deployPath?, branch?, deployMode?, buildOutputPath?, buildCommand?, preDeployCommand?, postDeployCommand?, enabled? }
   */
  static update = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const {
      deployPath,
      branch,
      deployMode,
      buildOutputPath,
      buildCommand,
      preDeployCommand,
      postDeployCommand,
      enabled,
    } = req.body;

    const projEnvRepo = AppDataSource.getRepository(ProjectEnvironment);
    const projectEnvironment = await projEnvRepo.findOne({
      where: { id: Number(id) },
    });

    if (!projectEnvironment) {
      throw new AppError('项目环境配置不存在', 404);
    }

    // 输入安全校验（防止命令注入）
    validateProjectEnvironmentInput({
      deployPath,
      branch,
      buildCommand,
      preDeployCommand,
      postDeployCommand,
    });

    // 验证 deployMode
    if (deployMode !== undefined && !['push', 'pull'].includes(deployMode)) {
      throw new AppError('部署模式只能是 push 或 pull', 400);
    }

    // 更新字段
    if (deployPath !== undefined) {
      projectEnvironment.deployPath = deployPath;
    }
    if (branch !== undefined) {
      projectEnvironment.branch = branch;
    }
    if (deployMode !== undefined) {
      projectEnvironment.deployMode = deployMode;
    }
    if (buildOutputPath !== undefined) {
      projectEnvironment.buildOutputPath = buildOutputPath;
    }
    if (buildCommand !== undefined) {
      projectEnvironment.buildCommand = buildCommand;
    }
    if (preDeployCommand !== undefined) {
      projectEnvironment.preDeployCommand = preDeployCommand;
    }
    if (postDeployCommand !== undefined) {
      projectEnvironment.postDeployCommand = postDeployCommand;
    }
    if (enabled !== undefined) {
      projectEnvironment.enabled = enabled;
    }

    await projEnvRepo.save(projectEnvironment);

    // 返回完整数据
    const result = await projEnvRepo.findOne({
      where: { id: projectEnvironment.id },
      relations: ['project', 'environment'],
    });

    res.json({
      success: true,
      data: result,
      message: '项目环境配置更新成功',
    });
  });

  /**
   * 删除项目环境配置
   * DELETE /api/project-environments/:id
   */
  static delete = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const projEnvRepo = AppDataSource.getRepository(ProjectEnvironment);

    const projectEnvironment = await projEnvRepo.findOne({
      where: { id: Number(id) },
      relations: ['deployments'],
    });

    if (!projectEnvironment) {
      throw new AppError('项目环境配置不存在', 404);
    }

    // 检查是否有关联的部署记录
    if (
      projectEnvironment.deployments &&
      projectEnvironment.deployments.length > 0
    ) {
      throw new AppError('该配置下存在部署记录，无法删除', 400);
    }

    await projEnvRepo.remove(projectEnvironment);

    res.json({
      success: true,
      message: '项目环境配置删除成功',
    });
  });

  /**
   * 切换项目环境配置的启用状态
   * POST /api/project-environments/:id/toggle
   */
  static toggle = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const projEnvRepo = AppDataSource.getRepository(ProjectEnvironment);

    const projectEnvironment = await projEnvRepo.findOne({
      where: { id: Number(id) },
    });

    if (!projectEnvironment) {
      throw new AppError('项目环境配置不存在', 404);
    }

    projectEnvironment.enabled = !projectEnvironment.enabled;
    await projEnvRepo.save(projectEnvironment);

    res.json({
      success: true,
      data: {
        id: projectEnvironment.id,
        enabled: projectEnvironment.enabled,
      },
      message: projectEnvironment.enabled ? '已启用' : '已禁用',
    });
  });
}
