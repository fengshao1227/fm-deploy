import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  OneToMany,
} from 'typeorm';
import { ProjectEnvironment } from './ProjectEnvironment';
import { User } from './User';
import { DeploymentLog } from './DeploymentLog';
import { DeploymentSnapshot } from './DeploymentSnapshot';

@Entity('deployments')
export class Deployment {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'project_environment_id' })
  projectEnvironmentId: number;

  @Column({ name: 'user_id' })
  userId: number;

  @Column({ length: 20 })
  status: 'pending' | 'running' | 'success' | 'failed' | 'rollback';

  @Column({ name: 'commit_hash', length: 40, nullable: true })
  commitHash: string;

  @Column({ name: 'commit_message', type: 'text', nullable: true })
  commitMessage: string;

  @Column({ name: 'started_at', type: 'timestamp', nullable: true })
  startedAt: Date;

  @Column({ name: 'finished_at', type: 'timestamp', nullable: true })
  finishedAt: Date;

  @Column({ name: 'error_message', type: 'text', nullable: true })
  errorMessage: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @ManyToOne(() => ProjectEnvironment, (projEnv) => projEnv.deployments)
  @JoinColumn({ name: 'project_environment_id' })
  projectEnvironment: ProjectEnvironment;

  @ManyToOne(() => User, (user) => user.deployments)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @OneToMany(() => DeploymentLog, (log) => log.deployment)
  logs: DeploymentLog[];

  @OneToMany(() => DeploymentSnapshot, (snapshot) => snapshot.deployment)
  snapshots: DeploymentSnapshot[];
}
