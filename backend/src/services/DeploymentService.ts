import { AppDataSource } from '../config/database';
import { Deployment } from '../models/Deployment';
import { DeploymentLog } from '../models/DeploymentLog';
import { DeploymentSnapshot } from '../models/DeploymentSnapshot';
import { ProjectEnvironment } from '../models/ProjectEnvironment';
import { createSSHService, SSHService } from './SSHService';
import { createLocalBuildService, LocalBuildService, BuildProgress } from './LocalBuildService';
import { EventEmitter } from 'events';
import * as path from 'path';

// 本地工作区目录（可通过环境变量配置）
const WORKSPACE_ROOT = process.env.WORKSPACE_ROOT || path.join(process.cwd(), '.workspace');

export interface DeploymentOptions {
  projectEnvironmentId: number;
  userId: number;
  envUrl?: string;
}

export interface DeploymentProgress {
  step: string;
  message: string;
  logType: 'stdout' | 'stderr' | 'info' | 'error';
}

export class DeploymentService extends EventEmitter {
  private deployment: Deployment | null = null;
  private sshService: SSHService | null = null;
  private localBuildService: LocalBuildService | null = null;
  private projectEnvironment: ProjectEnvironment | null = null;
  private envUrl?: string;

  /**
   * 创建部署任务
   */
  async createDeployment(options: DeploymentOptions): Promise<Deployment> {
    const deploymentRepo = AppDataSource.getRepository(Deployment);
    const projEnvRepo = AppDataSource.getRepository(ProjectEnvironment);

    // 获取项目环境配置
    const projectEnvironment = await projEnvRepo.findOne({
      where: { id: options.projectEnvironmentId },
      relations: ['project', 'environment'],
    });

    if (!projectEnvironment) {
      throw new Error('项目环境配置不存在');
    }

    if (!projectEnvironment.enabled) {
      throw new Error('该项目环境配置已禁用');
    }

    // 检查是否有正在运行的部署
    const runningDeployment = await deploymentRepo.findOne({
      where: {
        projectEnvironmentId: options.projectEnvironmentId,
        status: 'running',
      },
    });

    if (runningDeployment) {
      throw new Error('该项目环境已有部署任务正在执行');
    }

    // 创建部署记录
    const deployment = deploymentRepo.create({
      projectEnvironmentId: options.projectEnvironmentId,
      userId: options.userId,
      status: 'pending',
    });

    await deploymentRepo.save(deployment);

    this.deployment = deployment;
    this.projectEnvironment = projectEnvironment;
    this.envUrl = options.envUrl;

    return deployment;
  }

  /**
   * 执行部署
   */
  async execute(): Promise<void> {
    if (!this.deployment || !this.projectEnvironment) {
      throw new Error('部署任务未初始化');
    }

    const deployMode = this.projectEnvironment.deployMode || 'push';

    if (deployMode === 'push') {
      await this.executePushMode();
    } else {
      await this.executePullMode();
    }
  }

  /**
   * Push 模式部署：本地构建 + 上传到服务器
   */
  private async executePushMode(): Promise<void> {
    const deploymentRepo = AppDataSource.getRepository(Deployment);
    const environment = this.projectEnvironment!.environment;
    const project = this.projectEnvironment!.project;

    try {
      // 更新状态为执行中
      this.deployment!.status = 'running';
      this.deployment!.startedAt = new Date();
      await deploymentRepo.save(this.deployment!);

      // 检查 Git 仓库地址
      if (!project.gitRepo) {
        throw new Error('项目未配置 Git 仓库地址');
      }

      // 1. 初始化本地构建服务
      await this.log('info', '初始化本地构建环境...', 'init');
      this.localBuildService = createLocalBuildService({
        workspaceRoot: WORKSPACE_ROOT,
        projectKey: project.projectKey,
        gitRepo: project.gitRepo,
        branch: this.projectEnvironment!.branch,
      });

      // 监听构建进度
      this.localBuildService.on('progress', (progress: BuildProgress) => {
        this.log(progress.logType, progress.message, progress.step);
      });

      // 2. 克隆或拉取代码
      await this.log('info', '准备代码...', 'git');
      await this.localBuildService.cloneOrPull();

      // 获取提交信息
      const commitInfo = await this.localBuildService.getCommitInfo();
      this.deployment!.commitHash = commitInfo.hash;
      this.deployment!.commitMessage = commitInfo.message;
      await this.log(
        'info',
        `当前版本: ${commitInfo.hash.substring(0, 7)} - ${commitInfo.message}`,
        'git'
      );

      // 3. 执行构建
      if (this.projectEnvironment!.buildCommand) {
        await this.log('info', '开始本地构建...', 'build');
        await this.localBuildService.build(this.projectEnvironment!.buildCommand);
        await this.log('info', '✅ 本地构建完成', 'build');
      }

      // 4. 检查构建输出
      const buildOutputPath = this.projectEnvironment!.buildOutputPath || 'dist';
      if (!this.localBuildService.buildOutputExists(buildOutputPath)) {
        throw new Error(`构建输出目录不存在: ${buildOutputPath}`);
      }

      // 5. 连接远程服务器
      await this.log('info', '连接远程服务器...', 'upload');
      this.sshService = createSSHService({
        host: environment.sshHost,
        port: environment.sshPort,
        username: environment.sshUser,
        privateKeyPath: environment.sshKeyPath,
      });
      await this.sshService.connect();
      await this.log('info', `已连接到服务器: ${environment.sshHost}`, 'upload');

      // 6. 执行部署前命令（远程）
      if (this.projectEnvironment!.preDeployCommand) {
        await this.log('info', '执行部署前命令...', 'pre_deploy');
        await this.execCommand(
          this.projectEnvironment!.preDeployCommand,
          this.projectEnvironment!.deployPath,
          'pre_deploy'
        );
      }

      // 7. 备份远程现有目录（如果存在）
      const remoteDeployPath = this.projectEnvironment!.deployPath;
      const backupResult = await this.backupRemoteDirectory(remoteDeployPath);
      if (backupResult) {
        await this.log('info', `已备份现有版本: ${backupResult.backupName}`, 'backup');
      }

      // 8. 上传构建产物
      await this.log('info', '上传构建产物...', 'upload');
      const localOutputPath = this.localBuildService.getBuildOutputPath(buildOutputPath);

      const uploadResult = await this.sshService.uploadDirectory(
        localOutputPath,
        remoteDeployPath,
        (file, current, total) => {
          // 每 10 个文件记录一次进度，或者最后一个文件
          if (current % 10 === 0 || current === total) {
            this.log('info', `上传进度: ${current}/${total} 文件`, 'upload');
          }
        }
      );

      await this.log(
        'info',
        `✅ 上传完成: ${uploadResult.uploaded} 个文件`,
        'upload'
      );

      if (uploadResult.failed.length > 0) {
        await this.log(
          'stderr',
          `警告: ${uploadResult.failed.length} 个文件上传失败`,
          'upload'
        );
      }

      // 8. 创建或更新 .env 文件（如果提供了 envUrl）
      if (this.envUrl) {
        await this.log('info', '创建环境配置文件...', 'env');
        await this.createEnvFile(remoteDeployPath, this.envUrl);
        await this.log('info', '✅ 环境配置文件创建完成', 'env');
      }

      // 9. 执行部署后命令（远程）
      if (this.projectEnvironment!.postDeployCommand) {
        await this.log('info', '执行部署后命令...', 'post_deploy');
        await this.execCommand(
          this.projectEnvironment!.postDeployCommand,
          this.projectEnvironment!.deployPath,
          'post_deploy'
        );
      }

      // 部署成功
      this.deployment!.status = 'success';
      this.deployment!.finishedAt = new Date();
      await deploymentRepo.save(this.deployment!);

      await this.log('info', '✅ 部署成功!', 'complete');

    } catch (error) {
      // 部署失败
      const errorMessage = error instanceof Error ? error.message : '未知错误';
      this.deployment!.status = 'failed';
      this.deployment!.finishedAt = new Date();
      this.deployment!.errorMessage = errorMessage;
      await deploymentRepo.save(this.deployment!);

      await this.log('error', `❌ 部署失败: ${errorMessage}`, 'error');
      throw error;

    } finally {
      // 断开连接
      if (this.sshService) {
        this.sshService.disconnect();
      }
    }
  }

  /**
   * Pull 模式部署：在远程服务器上拉取代码并构建
   */
  private async executePullMode(): Promise<void> {
    const deploymentRepo = AppDataSource.getRepository(Deployment);
    const environment = this.projectEnvironment!.environment;

    try {
      // 更新状态为执行中
      this.deployment!.status = 'running';
      this.deployment!.startedAt = new Date();
      await deploymentRepo.save(this.deployment!);

      // 初始化SSH连接
      await this.log('info', '正在连接服务器...', 'connect');
      this.sshService = createSSHService({
        host: environment.sshHost,
        port: environment.sshPort,
        username: environment.sshUser,
        privateKeyPath: environment.sshKeyPath,
      });

      await this.sshService.connect();
      await this.log('info', `已连接到服务器: ${environment.sshHost}`, 'connect');

      // 检查部署目录
      const deployPath = this.projectEnvironment!.deployPath;
      await this.log('info', `检查部署目录: ${deployPath}`, 'check');

      const dirExists = await this.sshService.isDirectory(deployPath);
      if (!dirExists) {
        throw new Error(`部署目录不存在: ${deployPath}`);
      }

      // 执行部署前命令
      if (this.projectEnvironment!.preDeployCommand) {
        await this.log('info', '执行部署前命令...', 'pre_deploy');
        await this.execCommand(
          this.projectEnvironment!.preDeployCommand,
          deployPath,
          'pre_deploy'
        );
      }

      // 获取当前提交信息（部署前）
      const beforeCommit = await this.sshService.getGitCommit(deployPath);
      await this.log(
        'info',
        `当前版本: ${beforeCommit.hash.substring(0, 7)} - ${beforeCommit.message}`,
        'git'
      );

      // 创建快照（用于回滚）
      await this.createSnapshot(beforeCommit.hash);

      // 执行Git Pull
      await this.log('info', `拉取代码: ${this.projectEnvironment!.branch}`, 'git');
      const pullResult = await this.sshService.gitPull(
        deployPath,
        this.projectEnvironment!.branch
      );

      if (pullResult.code !== 0) {
        throw new Error(`Git Pull失败: ${pullResult.stderr}`);
      }

      await this.log('stdout', pullResult.stdout, 'git');

      // 获取新的提交信息
      const afterCommit = await this.sshService.getGitCommit(deployPath);
      this.deployment!.commitHash = afterCommit.hash;
      this.deployment!.commitMessage = afterCommit.message;
      await this.log(
        'info',
        `更新到版本: ${afterCommit.hash.substring(0, 7)} - ${afterCommit.message}`,
        'git'
      );

      // 执行构建命令
      if (this.projectEnvironment!.buildCommand) {
        await this.log('info', '执行构建命令...', 'build');
        await this.execCommand(
          this.projectEnvironment!.buildCommand,
          deployPath,
          'build'
        );
      }

      // 创建或更新 .env 文件（如果提供了 envUrl）
      if (this.envUrl) {
        await this.log('info', '创建环境配置文件...', 'env');
        await this.createEnvFile(deployPath, this.envUrl);
        await this.log('info', '✅ 环境配置文件创建完成', 'env');
      }

      // 执行部署后命令
      if (this.projectEnvironment!.postDeployCommand) {
        await this.log('info', '执行部署后命令...', 'post_deploy');
        await this.execCommand(
          this.projectEnvironment!.postDeployCommand,
          deployPath,
          'post_deploy'
        );
      }

      // 部署成功
      this.deployment!.status = 'success';
      this.deployment!.finishedAt = new Date();
      await deploymentRepo.save(this.deployment!);

      await this.log('info', '✅ 部署成功!', 'complete');

    } catch (error) {
      // 部署失败
      const errorMessage = error instanceof Error ? error.message : '未知错误';
      this.deployment!.status = 'failed';
      this.deployment!.finishedAt = new Date();
      this.deployment!.errorMessage = errorMessage;
      await deploymentRepo.save(this.deployment!);

      await this.log('error', `❌ 部署失败: ${errorMessage}`, 'error');
      throw error;

    } finally {
      // 断开SSH连接
      if (this.sshService) {
        this.sshService.disconnect();
      }
    }
  }

  /**
   * 执行回滚
   */
  async rollback(deploymentId: number): Promise<Deployment> {
    const deploymentRepo = AppDataSource.getRepository(Deployment);
    const snapshotRepo = AppDataSource.getRepository(DeploymentSnapshot);
    const projEnvRepo = AppDataSource.getRepository(ProjectEnvironment);

    // 获取原部署记录
    const originalDeployment = await deploymentRepo.findOne({
      where: { id: deploymentId },
      relations: ['snapshots'],
    });

    if (!originalDeployment) {
      throw new Error('部署记录不存在');
    }

    // 获取快照
    const snapshot = await snapshotRepo.findOne({
      where: { deploymentId },
    });

    if (!snapshot) {
      throw new Error('没有可用的快照进行回滚');
    }

    // 获取项目环境配置
    const projectEnvironment = await projEnvRepo.findOne({
      where: { id: originalDeployment.projectEnvironmentId },
      relations: ['project', 'environment'],
    });

    if (!projectEnvironment) {
      throw new Error('项目环境配置不存在');
    }

    // 创建回滚部署记录
    const rollbackDeployment = deploymentRepo.create({
      projectEnvironmentId: originalDeployment.projectEnvironmentId,
      userId: originalDeployment.userId,
      status: 'pending',
    });

    await deploymentRepo.save(rollbackDeployment);

    this.deployment = rollbackDeployment;
    this.projectEnvironment = projectEnvironment;

    const environment = projectEnvironment.environment;

    try {
      // 更新状态
      rollbackDeployment.status = 'running';
      rollbackDeployment.startedAt = new Date();
      await deploymentRepo.save(rollbackDeployment);

      // 初始化SSH连接
      await this.log('info', '正在连接服务器进行回滚...', 'connect');
      this.sshService = createSSHService({
        host: environment.sshHost,
        port: environment.sshPort,
        username: environment.sshUser,
        privateKeyPath: environment.sshKeyPath,
      });

      await this.sshService.connect();

      // 执行Git回滚
      await this.log('info', `回滚到版本: ${snapshot.commitHash.substring(0, 7)}`, 'rollback');
      const resetResult = await this.sshService.exec(
        `cd "${projectEnvironment.deployPath}" && git checkout ${snapshot.commitHash}`
      );

      if (resetResult.code !== 0) {
        throw new Error(`Git回滚失败: ${resetResult.stderr}`);
      }

      // 重新执行构建
      if (projectEnvironment.buildCommand) {
        await this.log('info', '重新执行构建...', 'build');
        await this.execCommand(
          projectEnvironment.buildCommand,
          projectEnvironment.deployPath,
          'build'
        );
      }

      // 执行部署后命令
      if (projectEnvironment.postDeployCommand) {
        await this.log('info', '执行部署后命令...', 'post_deploy');
        await this.execCommand(
          projectEnvironment.postDeployCommand,
          projectEnvironment.deployPath,
          'post_deploy'
        );
      }

      // 回滚成功
      rollbackDeployment.status = 'success';
      rollbackDeployment.finishedAt = new Date();
      rollbackDeployment.commitHash = snapshot.commitHash;
      await deploymentRepo.save(rollbackDeployment);

      await this.log('info', '✅ 回滚成功!', 'complete');

      return rollbackDeployment;

    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : '未知错误';
      rollbackDeployment.status = 'failed';
      rollbackDeployment.finishedAt = new Date();
      rollbackDeployment.errorMessage = errorMessage;
      await deploymentRepo.save(rollbackDeployment);

      await this.log('error', `❌ 回滚失败: ${errorMessage}`, 'error');
      throw error;

    } finally {
      if (this.sshService) {
        this.sshService.disconnect();
      }
    }
  }

  /**
   * 取消部署
   */
  async cancel(deploymentId: number): Promise<void> {
    const deploymentRepo = AppDataSource.getRepository(Deployment);
    const deployment = await deploymentRepo.findOne({
      where: { id: deploymentId },
    });

    if (!deployment) {
      throw new Error('部署记录不存在');
    }

    if (deployment.status !== 'pending' && deployment.status !== 'running') {
      throw new Error('只能取消待执行或执行中的部署');
    }

    deployment.status = 'failed';
    deployment.finishedAt = new Date();
    deployment.errorMessage = '用户取消部署';
    await deploymentRepo.save(deployment);

    // 断开SSH连接
    if (this.sshService) {
      this.sshService.disconnect();
    }
  }

  /**
   * 执行命令并记录日志
   */
  private async execCommand(
    command: string,
    workDir: string,
    step: string
  ): Promise<void> {
    if (!this.sshService) {
      throw new Error('SSH未连接');
    }

    const fullCommand = `cd "${workDir}" && ${command}`;

    const exitCode = await this.sshService.execWithCallback(
      fullCommand,
      (stdout) => {
        this.log('stdout', stdout, step);
      },
      (stderr) => {
        this.log('stderr', stderr, step);
      }
    );

    if (exitCode !== 0) {
      throw new Error(`命令执行失败 (exit code: ${exitCode})`);
    }
  }

  /**
   * 记录部署日志
   */
  private async log(
    logType: 'stdout' | 'stderr' | 'info' | 'error',
    message: string,
    step?: string
  ): Promise<void> {
    if (!this.deployment) return;

    const logRepo = AppDataSource.getRepository(DeploymentLog);
    const log = logRepo.create({
      deploymentId: this.deployment.id,
      logType,
      message,
    });

    await logRepo.save(log);

    // 发出日志事件（用于WebSocket推送）
    this.emit('log', {
      deploymentId: this.deployment.id,
      step,
      logType,
      message,
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * 创建部署快照（Pull 模式）
   */
  private async createSnapshot(commitHash: string): Promise<void> {
    if (!this.deployment) return;

    const snapshotRepo = AppDataSource.getRepository(DeploymentSnapshot);
    const snapshot = snapshotRepo.create({
      deploymentId: this.deployment.id,
      commitHash,
      deployMode: 'pull',
    });

    await snapshotRepo.save(snapshot);
  }

  /**
   * 备份远程目录（Push 模式）
   * 将现有的部署目录重命名为 dist_时间戳 格式
   */
  private async backupRemoteDirectory(
    deployPath: string
  ): Promise<{ backupPath: string; backupName: string } | null> {
    if (!this.sshService || !this.deployment) return null;

    try {
      // 检查部署目录是否存在
      const dirExists = await this.sshService.isDirectory(deployPath);
      if (!dirExists) {
        return null;
      }

      // 检查目录是否为空
      const checkEmpty = await this.sshService.exec(`ls -A "${deployPath}" 2>/dev/null | head -1`);
      if (!checkEmpty.stdout.trim()) {
        return null;
      }

      // 生成备份名称：dist_20251201_103000
      const now = new Date();
      const timestamp = now.toISOString()
        .replace(/[-:T]/g, '')
        .replace(/\..+/, '')
        .replace(/(\d{8})(\d{6})/, '$1_$2');

      const pathParts = deployPath.split('/');
      const dirName = pathParts.pop() || 'dist';
      const parentPath = pathParts.join('/');
      const backupName = `${dirName}_${timestamp}`;
      const backupPath = `${parentPath}/${backupName}`;

      // 执行重命名
      const mvResult = await this.sshService.exec(`mv "${deployPath}" "${backupPath}"`);
      if (mvResult.code !== 0) {
        await this.log('stderr', `备份失败: ${mvResult.stderr}`, 'backup');
        return null;
      }

      // 创建新的空目录
      await this.sshService.exec(`mkdir -p "${deployPath}"`);

      // 记录快照
      const snapshotRepo = AppDataSource.getRepository(DeploymentSnapshot);
      const snapshot = snapshotRepo.create({
        deploymentId: this.deployment.id,
        backupPath,
        backupName,
        deployMode: 'push',
      });
      await snapshotRepo.save(snapshot);

      return { backupPath, backupName };
    } catch (error) {
      await this.log('stderr', `备份过程出错: ${error}`, 'backup');
      return null;
    }
  }

  /**
   * 回滚到指定备份版本（Push 模式）
   */
  async rollbackToBackup(snapshotId: number, userId: number): Promise<Deployment> {
    const snapshotRepo = AppDataSource.getRepository(DeploymentSnapshot);
    const deploymentRepo = AppDataSource.getRepository(Deployment);
    const projEnvRepo = AppDataSource.getRepository(ProjectEnvironment);

    // 获取快照
    const snapshot = await snapshotRepo.findOne({
      where: { id: snapshotId },
      relations: ['deployment'],
    });

    if (!snapshot) {
      throw new Error('快照不存在');
    }

    if (!snapshot.backupPath || !snapshot.backupName) {
      throw new Error('该快照不支持回滚（非 Push 模式部署）');
    }

    // 获取原部署的项目环境配置
    const originalDeployment = snapshot.deployment;
    const projectEnvironment = await projEnvRepo.findOne({
      where: { id: originalDeployment.projectEnvironmentId },
      relations: ['project', 'environment'],
    });

    if (!projectEnvironment) {
      throw new Error('项目环境配置不存在');
    }

    // 创建回滚部署记录
    const rollbackDeployment = deploymentRepo.create({
      projectEnvironmentId: originalDeployment.projectEnvironmentId,
      userId,
      status: 'pending',
    });
    await deploymentRepo.save(rollbackDeployment);

    this.deployment = rollbackDeployment;
    this.projectEnvironment = projectEnvironment;

    const environment = projectEnvironment.environment;
    const deployPath = projectEnvironment.deployPath;

    try {
      rollbackDeployment.status = 'running';
      rollbackDeployment.startedAt = new Date();
      await deploymentRepo.save(rollbackDeployment);

      // 连接服务器
      await this.log('info', '正在连接服务器进行回滚...', 'connect');
      this.sshService = createSSHService({
        host: environment.sshHost,
        port: environment.sshPort,
        username: environment.sshUser,
        privateKeyPath: environment.sshKeyPath,
      });
      await this.sshService.connect();

      // 检查备份目录是否存在
      const backupExists = await this.sshService.isDirectory(snapshot.backupPath);
      if (!backupExists) {
        throw new Error(`备份目录不存在: ${snapshot.backupPath}`);
      }

      // 备份当前版本（以便再次回滚）
      await this.log('info', '备份当前版本...', 'backup');
      await this.backupRemoteDirectory(deployPath);

      // 恢复备份版本
      await this.log('info', `恢复版本: ${snapshot.backupName}`, 'rollback');

      // 删除当前目录（已经被备份了）
      await this.sshService.exec(`rm -rf "${deployPath}"`);

      // 将备份目录重命名为部署目录
      const mvResult = await this.sshService.exec(`mv "${snapshot.backupPath}" "${deployPath}"`);
      if (mvResult.code !== 0) {
        throw new Error(`恢复失败: ${mvResult.stderr}`);
      }

      // 执行部署后命令
      if (projectEnvironment.postDeployCommand) {
        await this.log('info', '执行部署后命令...', 'post_deploy');
        await this.execCommand(
          projectEnvironment.postDeployCommand,
          deployPath,
          'post_deploy'
        );
      }

      // 回滚成功
      rollbackDeployment.status = 'success';
      rollbackDeployment.finishedAt = new Date();
      rollbackDeployment.commitMessage = `回滚到版本: ${snapshot.backupName}`;
      await deploymentRepo.save(rollbackDeployment);

      await this.log('info', '✅ 回滚成功!', 'complete');

      return rollbackDeployment;

    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : '未知错误';
      rollbackDeployment.status = 'failed';
      rollbackDeployment.finishedAt = new Date();
      rollbackDeployment.errorMessage = errorMessage;
      await deploymentRepo.save(rollbackDeployment);

      await this.log('error', `❌ 回滚失败: ${errorMessage}`, 'error');
      throw error;

    } finally {
      if (this.sshService) {
        this.sshService.disconnect();
      }
    }
  }

  /**
   * 获取项目环境的所有可回滚版本
   */
  static async getBackupVersions(
    projectEnvironmentId: number
  ): Promise<Array<{
    id: number;
    backupName: string;
    backupPath: string;
    createdAt: Date;
    deploymentId: number;
  }>> {
    const snapshotRepo = AppDataSource.getRepository(DeploymentSnapshot);

    const snapshots = await snapshotRepo
      .createQueryBuilder('snapshot')
      .innerJoin('snapshot.deployment', 'deployment')
      .where('deployment.projectEnvironmentId = :projectEnvironmentId', { projectEnvironmentId })
      .andWhere('snapshot.deployMode = :mode', { mode: 'push' })
      .andWhere('snapshot.backupPath IS NOT NULL')
      .andWhere('snapshot.backupName IS NOT NULL')
      .orderBy('snapshot.createdAt', 'DESC')
      .getMany();

    return snapshots.map((s) => ({
      id: s.id,
      backupName: s.backupName,
      backupPath: s.backupPath,
      createdAt: s.createdAt,
      deploymentId: s.deploymentId,
    }));
  }

  /**
   * 创建或更新远程服务器上的 .env 文件
   */
  private async createEnvFile(deployPath: string, envUrl: string): Promise<void> {
    if (!this.sshService) {
      throw new Error('SSH 连接未建立');
    }

    // 构建 .env 文件内容
    const envContent = `UMI_APP_API_BASE_URL=${envUrl}`;

    // 远程 .env 文件路径
    const remoteEnvPath = path.posix.join(deployPath, '.env');

    // 先删除已存在的 .env 文件（如果存在）
    const checkCmd = `test -f ${remoteEnvPath} && rm ${remoteEnvPath} || true`;
    await this.sshService.exec(checkCmd);

    // 创建新的 .env 文件
    const createCmd = `echo '${envContent}' > ${remoteEnvPath}`;
    await this.sshService.exec(createCmd);

    // 设置文件权限（644）
    const chmodCmd = `chmod 644 ${remoteEnvPath}`;
    await this.sshService.exec(chmodCmd);
  }

  /**
   * 获取部署日志（支持分页和过滤）
   */
  static async getLogs(
    deploymentId: number,
    options?: {
      page?: number;
      pageSize?: number;
      logType?: string;
    }
  ): Promise<{ logs: DeploymentLog[]; total: number }> {
    const logRepo = AppDataSource.getRepository(DeploymentLog);
    const { page = 1, pageSize = 100, logType } = options || {};

    const queryBuilder = logRepo
      .createQueryBuilder('log')
      .where('log.deploymentId = :deploymentId', { deploymentId });

    // 按日志类型过滤
    if (logType) {
      queryBuilder.andWhere('log.logType = :logType', { logType });
    }

    // 分页
    const skip = (page - 1) * pageSize;
    queryBuilder.skip(skip).take(pageSize);

    // 排序
    queryBuilder.orderBy('log.timestamp', 'ASC');

    const [logs, total] = await queryBuilder.getManyAndCount();

    return { logs, total };
  }
}

/**
 * 创建部署服务实例
 */
export function createDeploymentService(): DeploymentService {
  return new DeploymentService();
}
