import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('environment_urls')
export class EnvironmentUrl {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 255, comment: '环境名称' })
  name: string;

  @Column({ type: 'varchar', length: 500, comment: '环境URL' })
  url: string;

  @Column({ type: 'text', nullable: true, comment: '描述信息' })
  description?: string;

  @Column({ type: 'int', default: 0, comment: '使用次数' })
  usageCount: number;

  @Column({ type: 'timestamp', nullable: true, comment: '最后使用时间' })
  lastUsedAt?: Date;

  @CreateDateColumn({ type: 'timestamp', comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ type: 'timestamp', comment: '更新时间' })
  updatedAt: Date;
}