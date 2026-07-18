import 'dotenv/config';
import { logger } from './logger';
import { startTryOnWorker } from './jobs/tryon.worker';
import { startCleanupWorker } from './jobs/cleanup.worker';

const renderWorker = startTryOnWorker();
const cleanupWorker = startCleanupWorker();

logger.info('Passress try-on worker started');

async function shutdown(): Promise<void> {
  await Promise.all([renderWorker.close(), cleanupWorker.close()]);
  process.exit(0);
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
