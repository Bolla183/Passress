import { Queue } from 'bullmq';
import IORedis from 'ioredis';
import { config } from './config';
import type { QueuedTryOnJobPayload } from './types/tryon';

export const TRYON_QUEUE_NAME = 'tryon-render';
export const CLEANUP_QUEUE_NAME = 'tryon-cleanup';

export function createRedisConnection(): IORedis {
  return new IORedis(config.redisUrl, { maxRetriesPerRequest: null });
}

const connection = createRedisConnection();

export const tryonQueue = new Queue<QueuedTryOnJobPayload>(TRYON_QUEUE_NAME, { connection });
export const cleanupQueue = new Queue(CLEANUP_QUEUE_NAME, { connection });

export async function scheduleCleanupJob(): Promise<void> {
  await cleanupQueue.add(
    'sweep-expired-jobs',
    {},
    {
      repeat: { every: 15 * 60 * 1000 },
      jobId: 'sweep-expired-jobs',
    },
  );
}
