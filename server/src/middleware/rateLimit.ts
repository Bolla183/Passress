import rateLimit from 'express-rate-limit';
import { config } from '../config';

export const createJobRateLimit = rateLimit({
  windowMs: config.rateLimit.windowMinutes * 60 * 1000,
  max: config.rateLimit.maxJobsPerWindow,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many try-on requests. Please wait a few minutes and try again.' },
});
