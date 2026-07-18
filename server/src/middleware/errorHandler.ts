import type { ErrorRequestHandler } from 'express';
import multer from 'multer';
import { ZodError } from 'zod';
import { ApiError } from '../errors';
import { InvalidImageError } from '../services/upload.service';
import { logger } from '../logger';

export const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  if (err instanceof ApiError) {
    res.status(err.statusCode).json({ error: err.message });
    return;
  }
  if (err instanceof ZodError) {
    res.status(400).json({ error: 'Invalid request.', details: err.issues });
    return;
  }
  if (err instanceof InvalidImageError) {
    res.status(400).json({ error: err.message });
    return;
  }
  if (err instanceof multer.MulterError) {
    res.status(400).json({ error: `Upload error: ${err.message}` });
    return;
  }

  logger.error({ err }, 'Unhandled error');
  res.status(500).json({ error: 'Something went wrong. Please try again.' });
};
