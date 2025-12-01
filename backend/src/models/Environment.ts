import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { ProjectEnvironment } from './ProjectEnvironment';

@Entity('environments')
export class Environment {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ length: 50 })
  name: string;

  @Column({ name: 'ssh_host', length: 255 })
  sshHost: string;

  @Column({ name: 'ssh_port', default: 22 })
  sshPort: number;

  @Column({ name: 'ssh_user', length: 50 })
  sshUser: string;

  @Column({ name: 'ssh_key_path', length: 255 })
  sshKeyPath: string;

  @Column({ type: 'text', nullable: true })
  description: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @OneToMany(() => ProjectEnvironment, (projEnv) => projEnv.environment)
  projectEnvironments: ProjectEnvironment[];
}
