import { Worker } from 'bullmq';
import { createRedisConnection, TRYON_QUEUE_NAME } from '../queue';
import { logger } from '../logger';
import { createTryOnProvider } from '../providers/provider-factory';
import { storageService } from '../services/storage.service';
import { getTryOnJob, markJobFailed, markJobProcessing, markJobSucceeded } from '../services/jobs.service';
import type { QueuedTryOnJobPayload } from '../types/tryon';

const provider = createTryOnProvider();

export function startTryOnWorker(): Worker<QueuedTryOnJobPayload> {
  const worker = new Worker<QueuedTryOnJobPayload>(
    TRYON_QUEUE_NAME,
    async (bullJob) => {
      const { jobId } = bullJob.data;
      const job = await getTryOnJob(jobId);
      if (!job) {
        logger.warn({ jobId }, 'Render job skipped: job record no longer exists');
        return;
      }

      await markJobProcessing(jobId, provider.name);

      const sourcePhoto = await storageService.getObjectBuffer(job.sourceImageKey);
      const result = await provider.render({
        sourcePhoto,
        productTitle: job.productTitle,
        colorName: job.colorName ?? undefined,
        garmentImageUrl: job.garmentImageUrl ?? undefined,
      });

      await markJobSucceeded(jobId, result.resultBuffer, result.contentType);
      logger.info({ jobId, provider: provider.name }, 'Render job succeeded');
    },
    { connection: createRedisConnection(), concurrency: 4 },
  );

  worker.on('failed', async (bullJob, error) => {
    const jobId = bullJob?.data.jobId;
    if (!jobId) return;
    logger.error({ jobId, error: error.message }, 'Render job failed');
    if ((bullJob?.attemptsMade ?? 0) >= (bullJob?.opts.attempts ?? 1)) {
      await markJobFailed(jobId, 'The try-on rendering failed. Please try again.');
    }
  });

  return worker;
}
