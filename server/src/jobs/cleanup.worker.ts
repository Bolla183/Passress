import { Worker } from 'bullmq';
import { CLEANUP_QUEUE_NAME, createRedisConnection } from '../queue';
import { logger } from '../logger';
import { deleteTryOnJob, listExpiredJobIds } from '../services/jobs.service';

/**
 * Sweeps and deletes jobs (and their stored photos) past their TTL. This is
 * what backs the frontend's promise that a customer's photo "isn't stored
 * or shared" beyond the preview session.
 */
export function startCleanupWorker(): Worker {
  return new Worker(
    CLEANUP_QUEUE_NAME,
    async () => {
      const expiredIds = await listExpiredJobIds();
      for (const id of expiredIds) {
        await deleteTryOnJob(id);
      }
      if (expiredIds.length) {
        logger.info({ count: expiredIds.length }, 'Swept expired try-on jobs');
      }
    },
    { connection: createRedisConnection(), concurrency: 1 },
  );
}
