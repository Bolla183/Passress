import { v4 as uuid } from 'uuid';
import { config } from '../config';
import { prisma } from '../db';
import { tryonQueue } from '../queue';
import { storageService } from './storage.service';
import type { CreateTryOnJobInput, TryOnJobView } from '../types/tryon';
import type { TryOnJob } from '@prisma/client';

const PROGRESS_BY_STATUS: Record<TryOnJob['status'], number> = {
  queued: 5,
  processing: 55,
  succeeded: 100,
  failed: 100,
};

function sourceKeyFor(jobId: string): string {
  return `uploads/${jobId}/source.jpg`;
}

function resultKeyFor(jobId: string): string {
  return `results/${jobId}/result.png`;
}

export async function createTryOnJob(
  input: CreateTryOnJobInput,
  sourcePhoto: Buffer,
): Promise<TryOnJob> {
  const id = uuid();
  const expiresAt = new Date(Date.now() + config.jobTtlHours * 60 * 60 * 1000);
  const sourceImageKey = sourceKeyFor(id);

  await storageService.putObject(sourceImageKey, sourcePhoto, 'image/jpeg');

  const job = await prisma.tryOnJob.create({
    data: {
      id,
      shopDomain: input.shopDomain,
      productId: input.productId,
      variantId: input.variantId,
      productTitle: input.productTitle,
      colorName: input.colorName,
      garmentImageUrl: input.garmentImageUrl,
      sourceImageKey,
      expiresAt,
    },
  });

  await tryonQueue.add('render', { jobId: job.id }, { jobId: job.id, attempts: 2, backoff: { type: 'exponential', delay: 2000 } });

  return job;
}

export async function getTryOnJob(id: string): Promise<TryOnJob | null> {
  return prisma.tryOnJob.findUnique({ where: { id } });
}

export async function markJobProcessing(id: string, provider: string): Promise<void> {
  await prisma.tryOnJob.update({
    where: { id },
    data: { status: 'processing', provider, attempts: { increment: 1 } },
  });
}

export async function markJobSucceeded(id: string, resultBuffer: Buffer, contentType: string): Promise<void> {
  const resultImageKey = resultKeyFor(id);
  await storageService.putObject(resultImageKey, resultBuffer, contentType);
  await prisma.tryOnJob.update({
    where: { id },
    data: { status: 'succeeded', resultImageKey },
  });
}

export async function markJobFailed(id: string, errorMessage: string): Promise<void> {
  await prisma.tryOnJob.update({
    where: { id },
    data: { status: 'failed', errorMessage },
  });
}

export async function deleteTryOnJob(id: string): Promise<void> {
  const job = await prisma.tryOnJob.findUnique({ where: { id } });
  if (!job) return;

  await storageService.deleteObject(job.sourceImageKey);
  if (job.resultImageKey) await storageService.deleteObject(job.resultImageKey);
  await prisma.tryOnJob.delete({ where: { id } });
}

export async function listExpiredJobIds(): Promise<string[]> {
  const expired = await prisma.tryOnJob.findMany({
    where: { expiresAt: { lt: new Date() } },
    select: { id: true },
  });
  return expired.map((job) => job.id);
}

export async function toJobView(job: TryOnJob): Promise<TryOnJobView> {
  const resultUrl = job.status === 'succeeded' && job.resultImageKey
    ? await storageService.getSignedDownloadUrl(job.resultImageKey)
    : null;

  return {
    jobId: job.id,
    status: job.status,
    progress: PROGRESS_BY_STATUS[job.status],
    resultUrl,
    error: job.status === 'failed' ? job.errorMessage ?? 'Rendering failed.' : null,
    createdAt: job.createdAt.toISOString(),
    updatedAt: job.updatedAt.toISOString(),
    expiresAt: job.expiresAt.toISOString(),
  };
}
