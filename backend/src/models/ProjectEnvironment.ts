import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  OneToMany,
  Unique,
} from 'typeorm';
import { Project } from './Project';
import { Environment } from './Environment';
import { Deployment } from './Deployment';

@Entity('project_environments')
@Unique(['projectId', 'environmentId'])
export class ProjectEnvironment {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'project_id' })
  projectId: number;

  @Column({ name: 'environment_id' })
  environmentId: number;

  @Column({ name: 'deploy_path', length: 255 })
  deployPath: string;

  @Column({ length: 100, default: 'master' })
  branch: string;

  @Column({ name: 'deploy_mode', length: 20, default: 'push' })
  deployMode: 'push' | 'pull';

  @Column({ name: 'build_output_path', length: 255, default: 'dist' })
  buildOutputPath: string;

  @Column({ name: 'build_command', type: 'text', nullable: true })
  buildCommand: string;

  @Column({ name: 'pre_deploy_command', type: 'text', nullable: true })
  preDeployCommand: string;

  @Column({ name: 'post_deploy_command', type: 'text', nullable: true })
  postDeployCommand: string;

  @Column({ default: true })
  enabled: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @ManyToOne(() => Project, (project) => project.projectEnvironments)
  @JoinColumn({ name: 'project_id' })
  project: Project;

  @ManyToOne(() => Environment, (environment) => environment.projectEnvironments)
  @JoinColumn({ name: 'environment_id' })
  environment: Environment;

  @OneToMany(() => Deployment, (deployment) => deployment.projectEnvironment)
  deployments: Deployment[];
}
