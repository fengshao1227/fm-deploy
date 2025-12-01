import Redis from 'ioredis';
import dotenv from 'dotenv';

dotenv.config();

export const redisClient = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
  password: process.env.REDIS_PASSWORD || undefined,
  db: parseInt(process.env.REDIS_DB || '0'),
  retryStrategy: (times) => {
    const delay = Math.min(times * 50, 2000);
    return delay;
  },
  maxRetriesPerRequest: 3,
});

redisClient.on('connect', () => {
  console.log('Redis 连接成功');
});

redisClient.on('error', (err) => {
  console.error('Redis 连接错误:', err);
});

export default redisClient;
