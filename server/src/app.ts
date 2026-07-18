import express from 'express';
import pinoHttp from 'pino-http';
import { shopCors } from './middleware/cors';
import { errorHandler } from './middleware/errorHandler';
import { healthRouter } from './routes/health';
import { tryOnJobsRouter } from './routes/tryonJobs';
import { logger } from './logger';

export function createApp(): express.Express {
  const app = express();

  app.use(pinoHttp({ logger }));
  app.use(shopCors);
  app.use(healthRouter);
  app.use('/v1/tryon/jobs', tryOnJobsRouter);

  app.use((_req, res) => {
    res.status(404).json({ error: 'Not found.' });
  });

  app.use(errorHandler);

  return app;
}
