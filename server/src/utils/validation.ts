import { z } from 'zod';

export const createJobBodySchema = z.object({
  shopDomain: z.string().min(3).max(255),
  productId: z.string().min(1).max(255),
  variantId: z.string().max(255).optional(),
  productTitle: z.string().min(1).max(255),
  colorName: z.string().max(120).optional(),
  garmentImageUrl: z.string().url().max(2048).optional(),
});

export type CreateJobBody = z.infer<typeof createJobBodySchema>;

export const jobIdParamSchema = z.object({
  id: z.string().uuid(),
});
