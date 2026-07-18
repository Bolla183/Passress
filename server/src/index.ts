import 'dotenv/config';
import { createApp } from './app';
import { config } from './config';
import { logger } from './logger';
import { scheduleCleanupJob } from './queue';

async function main(): Promise<void> {
  await scheduleCleanupJob();

  const app = createApp();
  app.listen(config.port, () => {
    logger.info({ port: config.port }, 'Passress try-on API listening');
  });
}

main().catch((err) => {
  logger.error({ err }, 'Failed to start API server');
  process.exit(1);
});
