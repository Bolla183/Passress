import { Router } from 'express';
import multer from 'multer';
import { config } from '../config';
import { NotFoundError, BadRequestError } from '../errors';
import { createJobRateLimit } from '../middleware/rateLimit';
import { sanitizeUploadedImage } from '../services/upload.service';
import { createTryOnJob, deleteTryOnJob, getTryOnJob, toJobView } from '../services/jobs.service';
import { createJobBodySchema, jobIdParamSchema } from '../utils/validation';

export const tryOnJobsRouter = Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: config.maxUploadBytes, files: 1 },
});

tryOnJobsRouter.post('/', createJobRateLimit, upload.single('photo'), async (req, res, next) => {
  try {
    if (!req.file) {
      throw new BadRequestError('A "photo" file is required.');
    }
    const body = createJobBodySchema.parse(req.body);
    const sanitized = await sanitizeUploadedImage(req.file.buffer);

    const job = await createTryOnJob(body, sanitized.buffer);
    const view = await toJobView(job);

    res.status(201).json({
      jobId: view.jobId,
      status: view.status,
      createdAt: view.createdAt,
      expiresAt: view.expiresAt,
      pollUrl: `/v1/tryon/jobs/${view.jobId}`,
    });
  } catch (err) {
    next(err);
  }
});

tryOnJobsRouter.get('/:id', async (req, res, next) => {
  try {
    const { id } = jobIdParamSchema.parse(req.params);
    const job = await getTryOnJob(id);
    if (!job) throw new NotFoundError('Try-on job not found.');

    res.status(200).json(await toJobView(job));
  } catch (err) {
    next(err);
  }
});

tryOnJobsRouter.get('/:id/result', async (req, res, next) => {
  try {
    const { id } = jobIdParamSchema.parse(req.params);
    const job = await getTryOnJob(id);
    if (!job) throw new NotFoundError('Try-on job not found.');

    if (job.status === 'failed') {
      res.status(409).json({ error: job.errorMessage ?? 'Rendering failed.' });
      return;
    }
    if (job.status !== 'succeeded' || !job.resultImageKey) {
      res.status(202).json({ status: job.status });
      return;
    }

    const view = await toJobView(job);
    res.redirect(302, view.resultUrl as string);
  } catch (err) {
    next(err);
  }
});

tryOnJobsRouter.delete('/:id', async (req, res, next) => {
  try {
    const { id } = jobIdParamSchema.parse(req.params);
    await deleteTryOnJob(id);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});
