import { DataSource } from 'typeorm';
import dotenv from 'dotenv';

dotenv.config();

export const AppDataSource = new DataSource({
  type: 'mysql',
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '3306'),
  username: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || 'password',
  database: process.env.DB_NAME || 'fm_deploy',
  synchronize: process.env.NODE_ENV === 'development', // 仅开发环境自动同步
  logging: process.env.NODE_ENV === 'development',
  entities: [__dirname + '/../models/**/*.{ts,js}'],
  migrations: [__dirname + '/../migrations/**/*.{ts,js}'],
  subscribers: [],
  charset: 'utf8mb4',
});
