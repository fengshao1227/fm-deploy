import { spawn, ChildProcess } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import { EventEmitter } from 'events';

export interface LocalBuildConfig {
  workspaceRoot: string;  // 本地工作区根目录
  projectKey: string;     // 项目标识
  gitRepo: string;        // Git 仓库地址
  branch: string;         // 分支
}

export interface BuildProgress {
  step: string;
  message: string;
  logType: 'stdout' | 'stderr' | 'info' | 'error';
}

export class LocalBuildService extends EventEmitter {
  private config: LocalBuildConfig;
  private projectPath: string;
  private currentProcess: ChildProcess | null = null;
  private cancelled = false;

  constructor(config: LocalBuildConfig) {
    super();
    this.config = config;
    // 项目工作目录: {workspaceRoot}/{projectKey}
    this.projectPath = path.join(config.workspaceRoot, config.projectKey);
  }

  /**
   * 获取项目本地路径
   */
  getProjectPath(): string {
    return this.projectPath;
  }

  /**
   * 获取构建输出路径
   */
  getBuildOutputPath(buildOutputDir: string): string {
    return path.join(this.projectPath, buildOutputDir);
  }

  /**
   * 确保工作区目录存在
   */
  private ensureWorkspaceExists(): void {
    if (!fs.existsSync(this.config.workspaceRoot)) {
      fs.mkdirSync(this.config.workspaceRoot, { recursive: true });
    }
  }

  /**
   * 检查项目是否已克隆
   */
  isProjectCloned(): boolean {
    return fs.existsSync(path.join(this.projectPath, '.git'));
  }

  /**
   * 克隆或拉取代码
   */
  async cloneOrPull(): Promise<void> {
    this.ensureWorkspaceExists();

    if (this.isProjectCloned()) {
      // 已存在，执行 pull
      this.emit('progress', {
        step: 'git',
        message: `拉取最新代码: ${this.config.branch}`,
        logType: 'info',
      } as BuildProgress);

      await this.execCommand(
        'git',
        ['fetch', 'origin'],
        this.projectPath
      );

      await this.execCommand(
        'git',
        ['checkout', this.config.branch],
        this.projectPath
      );

      await this.execCommand(
        'git',
        ['pull', 'origin', this.config.branch],
        this.projectPath
      );
    } else {
      // 不存在，执行 clone
      this.emit('progress', {
        step: 'git',
        message: `克隆仓库: ${this.config.gitRepo}`,
        logType: 'info',
      } as BuildProgress);

      await this.execCommand(
        'git',
        ['clone', '-b', this.config.branch, this.config.gitRepo, this.config.projectKey],
        this.config.workspaceRoot
      );
    }
  }

  /**
   * 获取当前提交信息
   */
  async getCommitInfo(): Promise<{ hash: string; message: string; author: string; date: string }> {
    const result = await this.execCommand(
      'git',
      ['log', '-1', '--format="%H|%s|%an|%ai"'],
      this.projectPath,
      true
    );

    // 移除可能的引号并分割
    const output = result.trim().replace(/^"|"$/g, '');
    const [hash, message, author, date] = output.split('|');
    return { hash, message, author, date };
  }

  /**
   * 执行构建命令
   */
  async build(buildCommand: string): Promise<void> {
    if (!buildCommand) {
      this.emit('progress', {
        step: 'build',
        message: '无构建命令，跳过构建步骤',
        logType: 'info',
      } as BuildProgress);
      return;
    }

    this.emit('progress', {
      step: 'build',
      message: `执行构建命令: ${buildCommand}`,
      logType: 'info',
    } as BuildProgress);

    // 解析命令（支持 && 连接的多命令）
    const commands = buildCommand.split('&&').map(cmd => cmd.trim());

    for (const cmd of commands) {
      if (this.cancelled) {
        throw new Error('构建已取消');
      }

      const [command, ...args] = this.parseCommand(cmd);
      await this.execCommand(command, args, this.projectPath);
    }
  }

  /**
   * 解析命令字符串为命令和参数数组
   */
  private parseCommand(cmdString: string): string[] {
    // 简单解析，处理引号内的空格
    const parts: string[] = [];
    let current = '';
    let inQuote = false;
    let quoteChar = '';

    for (const char of cmdString) {
      if ((char === '"' || char === "'") && !inQuote) {
        inQuote = true;
        quoteChar = char;
      } else if (char === quoteChar && inQuote) {
        inQuote = false;
        quoteChar = '';
      } else if (char === ' ' && !inQuote) {
        if (current) {
          parts.push(current);
          current = '';
        }
      } else {
        current += char;
      }
    }

    if (current) {
      parts.push(current);
    }

    return parts;
  }

  /**
   * 执行命令
   */
  private execCommand(
    command: string,
    args: string[],
    cwd: string,
    captureOutput = false
  ): Promise<string> {
    return new Promise((resolve, reject) => {
      // 根据平台选择 shell
      const isWindows = process.platform === 'win32';
      const shell = isWindows ? true : '/bin/bash';

      const proc = spawn(command, args, {
        cwd,
        shell,
        env: {
          ...process.env,
          // 确保 npm/node 可用
          PATH: process.env.PATH,
        },
      });

      this.currentProcess = proc;
      let output = '';

      proc.stdout?.on('data', (data: Buffer) => {
        const text = data.toString();
        output += text;
        if (!captureOutput) {
          this.emit('progress', {
            step: 'build',
            message: text,
            logType: 'stdout',
          } as BuildProgress);
        }
      });

      proc.stderr?.on('data', (data: Buffer) => {
        const text = data.toString();
        if (!captureOutput) {
          this.emit('progress', {
            step: 'build',
            message: text,
            logType: 'stderr',
          } as BuildProgress);
        }
      });

      proc.on('close', (code) => {
        this.currentProcess = null;
        if (code === 0) {
          resolve(output);
        } else {
          reject(new Error(`命令执行失败 (exit code: ${code}): ${command} ${args.join(' ')}`));
        }
      });

      proc.on('error', (err) => {
        this.currentProcess = null;
        reject(new Error(`命令执行错误: ${err.message}`));
      });
    });
  }

  /**
   * 取消当前操作
   */
  cancel(): void {
    this.cancelled = true;
    if (this.currentProcess) {
      this.currentProcess.kill('SIGTERM');
    }
  }

  /**
   * 清理项目目录
   */
  async cleanup(): Promise<void> {
    if (fs.existsSync(this.projectPath)) {
      fs.rmSync(this.projectPath, { recursive: true, force: true });
    }
  }

  /**
   * 检查构建输出目录是否存在
   */
  buildOutputExists(buildOutputDir: string): boolean {
    const outputPath = this.getBuildOutputPath(buildOutputDir);
    return fs.existsSync(outputPath) && fs.statSync(outputPath).isDirectory();
  }
}

/**
 * 创建本地构建服务实例
 */
export function createLocalBuildService(config: LocalBuildConfig): LocalBuildService {
  return new LocalBuildService(config);
}
