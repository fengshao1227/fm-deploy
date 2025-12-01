import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { Deployment } from './Deployment';

@Entity('deployment_logs')
@Index(['deploymentId'])
export class DeploymentLog {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'deployment_id' })
  deploymentId: number;

  @Column({ name: 'log_type', length: 20 })
  logType: 'stdout' | 'stderr' | 'info' | 'error';

  @Column({ type: 'text' })
  message: string;

  @CreateDateColumn({ name: 'timestamp' })
  timestamp: Date;

  @ManyToOne(() => Deployment, (deployment) => deployment.logs, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'deployment_id' })
  deployment: Deployment;
}
