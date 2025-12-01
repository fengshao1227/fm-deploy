import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Deployment } from './Deployment';

@Entity('deployment_snapshots')
export class DeploymentSnapshot {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'deployment_id' })
  deploymentId: number;

  @Column({ name: 'commit_hash', length: 40, nullable: true })
  commitHash: string;

  @Column({ name: 'snapshot_path', length: 255, nullable: true })
  snapshotPath: string;

  @Column({ name: 'backup_path', length: 255, nullable: true })
  backupPath: string;

  @Column({ name: 'backup_name', length: 100, nullable: true })
  backupName: string;

  @Column({ name: 'deploy_mode', length: 20, default: 'pull' })
  deployMode: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @ManyToOne(() => Deployment, (deployment) => deployment.snapshots, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'deployment_id' })
  deployment: Deployment;
}
