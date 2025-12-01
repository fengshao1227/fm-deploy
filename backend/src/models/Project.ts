import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { ProjectEnvironment } from './ProjectEnvironment';

@Entity('projects')
export class Project {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ length: 100 })
  name: string;

  @Column({ name: 'project_key', unique: true, length: 50 })
  projectKey: string;

  @Column({ length: 20 })
  type: 'frontend' | 'backend';

  @Column({ name: 'git_repo', length: 255, nullable: true })
  gitRepo: string;

  @Column({ type: 'text', nullable: true })
  description: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @OneToMany(() => ProjectEnvironment, (projEnv) => projEnv.project)
  projectEnvironments: ProjectEnvironment[];
}
