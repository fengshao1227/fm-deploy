import { Client, ConnectConfig, SFTPWrapper } from 'ssh2';
import * as fs from 'fs';
import * as path from 'path';
import { createReadStream, readdirSync, statSync } from 'fs';

export interface SSHConfig {
  host: string;
  port: number;
  username: string;
  privateKeyPath: string;
}

export interface CommandResult {
  code: number;
  stdout: string;
  stderr: string;
}

export interface SSHConnectionResult {
  success: boolean;
  message: string;
  serverInfo?: {
    hostname: string;
    platform: string;
    uptime: string;
  };
}

export class SSHService {
  private config: SSHConfig;
  private client: Client | null = null;

  constructor(config: SSHConfig) {
    this.config = config;
  }

  /**
   * 获取SSH连接配置
   */
  private getConnectConfig(): ConnectConfig {
    const privateKeyPath = this.config.privateKeyPath;

    // 支持相对路径和~路径
    let resolvedPath = privateKeyPath;
    if (privateKeyPath.startsWith('~')) {
      resolvedPath = path.join(process.env.HOME || '', privateKeyPath.slice(1));
    } else if (!path.isAbsolute(privateKeyPath)) {
      resolvedPath = path.resolve(privateKeyPath);
    }

    if (!fs.existsSync(resolvedPath)) {
      throw new Error(`SSH私钥文件不存在: ${resolvedPath}`);
    }

    return {
      host: this.config.host,
      port: this.config.port,
      username: this.config.username,
      privateKey: fs.readFileSync(resolvedPath),
      readyTimeout: 10000,
      keepaliveInterval: 10000,
    };
  }

  /**
   * 建立SSH连接
   */
  async connect(): Promise<Client> {
    return new Promise((resolve, reject) => {
      const client = new Client();
      const config = this.getConnectConfig();

      client.on('ready', () => {
        this.client = client;
        resolve(client);
      });

      client.on('error', (err) => {
        reject(new Error(`SSH连接失败: ${err.message}`));
      });

      client.connect(config);
    });
  }

  /**
   * 断开SSH连接
   */
  disconnect(): void {
    if (this.client) {
      this.client.end();
      this.client = null;
    }
  }

  /**
   * 测试SSH连接
   */
  async testConnection(): Promise<SSHConnectionResult> {
    try {
      await this.connect();

      // 获取服务器基本信息
      const hostnameResult = await this.exec('hostname');
      const platformResult = await this.exec('uname -a');
      const uptimeResult = await this.exec('uptime');

      const serverInfo = {
        hostname: hostnameResult.stdout.trim(),
        platform: platformResult.stdout.trim(),
        uptime: uptimeResult.stdout.trim(),
      };

      this.disconnect();

      return {
        success: true,
        message: 'SSH连接成功',
        serverInfo,
      };
    } catch (error) {
      this.disconnect();
      return {
        success: false,
        message: error instanceof Error ? error.message : '未知错误',
      };
    }
  }

  /**
   * 执行远程命令
   */
  async exec(command: string): Promise<CommandResult> {
    if (!this.client) {
      await this.connect();
    }

    return new Promise((resolve, reject) => {
      this.client!.exec(command, (err, stream) => {
        if (err) {
          reject(new Error(`执行命令失败: ${err.message}`));
          return;
        }

        let stdout = '';
        let stderr = '';

        stream.on('close', (code: number) => {
          resolve({ code, stdout, stderr });
        });

        stream.on('data', (data: Buffer) => {
          stdout += data.toString();
        });

        stream.stderr.on('data', (data: Buffer) => {
          stderr += data.toString();
        });
      });
    });
  }

  /**
   * 执行命令并实时输出（用于部署日志）
   */
  async execWithCallback(
    command: string,
    onStdout: (data: string) => void,
    onStderr: (data: string) => void
  ): Promise<number> {
    if (!this.client) {
      await this.connect();
    }

    return new Promise((resolve, reject) => {
      this.client!.exec(command, (err, stream) => {
        if (err) {
          reject(new Error(`执行命令失败: ${err.message}`));
          return;
        }

        stream.on('close', (code: number) => {
          resolve(code);
        });

        stream.on('data', (data: Buffer) => {
          onStdout(data.toString());
        });

        stream.stderr.on('data', (data: Buffer) => {
          onStderr(data.toString());
        });
      });
    });
  }

  /**
   * 执行多个命令（顺序执行）
   */
  async execMultiple(commands: string[]): Promise<CommandResult[]> {
    const results: CommandResult[] = [];

    for (const command of commands) {
      const result = await this.exec(command);
      results.push(result);

      // 如果命令执行失败，停止后续命令
      if (result.code !== 0) {
        break;
      }
    }

    return results;
  }

  /**
   * 检查远程文件/目录是否存在
   */
  async exists(remotePath: string): Promise<boolean> {
    const result = await this.exec(`test -e "${remotePath}" && echo "exists" || echo "not_exists"`);
    return result.stdout.trim() === 'exists';
  }

  /**
   * 检查远程目录是否存在
   */
  async isDirectory(remotePath: string): Promise<boolean> {
    const result = await this.exec(`test -d "${remotePath}" && echo "yes" || echo "no"`);
    return result.stdout.trim() === 'yes';
  }

  /**
   * 创建远程目录（递归）
   */
  async mkdir(remotePath: string): Promise<CommandResult> {
    return this.exec(`mkdir -p "${remotePath}"`);
  }

  /**
   * 获取Git仓库当前分支
   */
  async getGitBranch(remotePath: string): Promise<string> {
    const result = await this.exec(`cd "${remotePath}" && git branch --show-current`);
    if (result.code !== 0) {
      throw new Error(`获取Git分支失败: ${result.stderr}`);
    }
    return result.stdout.trim();
  }

  /**
   * 获取Git最新提交信息
   */
  async getGitCommit(remotePath: string): Promise<{ hash: string; message: string; author: string; date: string }> {
    const result = await this.exec(
      `cd "${remotePath}" && git log -1 --format="%H|%s|%an|%ai"`
    );
    if (result.code !== 0) {
      throw new Error(`获取Git提交信息失败: ${result.stderr}`);
    }

    const [hash, message, author, date] = result.stdout.trim().split('|');
    return { hash, message, author, date };
  }

  /**
   * 执行Git Pull
   */
  async gitPull(remotePath: string, branch: string): Promise<CommandResult> {
    return this.exec(`cd "${remotePath}" && git fetch origin && git checkout ${branch} && git pull origin ${branch}`);
  }

  /**
   * 切换Git分支
   */
  async gitCheckout(remotePath: string, branch: string): Promise<CommandResult> {
    return this.exec(`cd "${remotePath}" && git checkout ${branch}`);
  }

  /**
   * 获取SFTP客户端
   */
  private async getSftp(): Promise<SFTPWrapper> {
    if (!this.client) {
      await this.connect();
    }

    return new Promise((resolve, reject) => {
      this.client!.sftp((err, sftp) => {
        if (err) {
          reject(new Error(`SFTP连接失败: ${err.message}`));
          return;
        }
        resolve(sftp);
      });
    });
  }

  /**
   * 上传单个文件
   */
  async uploadFile(
    localPath: string,
    remotePath: string,
    onProgress?: (transferred: number, total: number) => void
  ): Promise<void> {
    const sftp = await this.getSftp();
    const stats = statSync(localPath);
    const total = stats.size;
    let transferred = 0;

    return new Promise((resolve, reject) => {
      const readStream = createReadStream(localPath);
      const writeStream = sftp.createWriteStream(remotePath);

      readStream.on('data', (chunk: string | Buffer) => {
        transferred += typeof chunk === 'string' ? chunk.length : chunk.length;
        onProgress?.(transferred, total);
      });

      writeStream.on('close', () => {
        resolve();
      });

      writeStream.on('error', (err: Error) => {
        reject(new Error(`上传文件失败 ${localPath}: ${err.message}`));
      });

      readStream.pipe(writeStream);
    });
  }

  /**
   * 在远程创建目录（通过SFTP）
   */
  async sftpMkdir(remotePath: string): Promise<void> {
    const sftp = await this.getSftp();

    return new Promise((resolve, reject) => {
      sftp.mkdir(remotePath, (err) => {
        // SFTP error code 4 = directory already exists
        if (err && (err as NodeJS.ErrnoException).code !== 'EEXIST' &&
            (err as { code?: number }).code !== 4) {
          reject(new Error(`创建目录失败 ${remotePath}: ${err.message}`));
          return;
        }
        resolve();
      });
    });
  }

  /**
   * 递归上传目录
   */
  async uploadDirectory(
    localDir: string,
    remoteDir: string,
    onProgress?: (file: string, current: number, total: number) => void
  ): Promise<{ uploaded: number; failed: string[] }> {
    // 获取所有文件列表
    const files = this.getAllFiles(localDir);
    const total = files.length;
    let current = 0;
    const failed: string[] = [];

    // 确保远程根目录存在
    await this.exec(`mkdir -p "${remoteDir}"`);

    for (const localFile of files) {
      const relativePath = path.relative(localDir, localFile);
      const remoteFile = path.posix.join(remoteDir, relativePath.replace(/\\/g, '/'));
      const remoteFileDir = path.posix.dirname(remoteFile);

      try {
        // 确保远程目录存在
        await this.exec(`mkdir -p "${remoteFileDir}"`);

        // 上传文件
        await this.uploadFile(localFile, remoteFile);

        current++;
        onProgress?.(relativePath, current, total);
      } catch (error) {
        failed.push(relativePath);
        current++;
        onProgress?.(relativePath, current, total);
      }
    }

    return { uploaded: total - failed.length, failed };
  }

  /**
   * 递归获取目录下所有文件
   */
  private getAllFiles(dir: string): string[] {
    const files: string[] = [];

    const items = readdirSync(dir);
    for (const item of items) {
      const fullPath = path.join(dir, item);
      const stats = statSync(fullPath);

      if (stats.isDirectory()) {
        files.push(...this.getAllFiles(fullPath));
      } else {
        files.push(fullPath);
      }
    }

    return files;
  }
}

/**
 * 创建SSH服务实例的工厂函数
 */
export function createSSHService(config: SSHConfig): SSHService {
  return new SSHService(config);
}
