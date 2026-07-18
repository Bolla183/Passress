export type TryOnJobStatus = 'queued' | 'processing' | 'succeeded' | 'failed';

export interface CreateTryOnJobInput {
  shopDomain: string;
  productId: string;
  variantId?: string;
  productTitle: string;
  colorName?: string;
  garmentImageUrl?: string;
}

export interface TryOnJobView {
  jobId: string;
  status: TryOnJobStatus;
  progress: number;
  resultUrl: string | null;
  error: string | null;
  createdAt: string;
  updatedAt: string;
  expiresAt: string;
}

export interface QueuedTryOnJobPayload {
  jobId: string;
}
