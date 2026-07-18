import cors from 'cors';
import { config } from '../config';
import { ApiError } from '../errors';

/**
 * The Shopify theme is the only intended caller of this API. Restricting
 * CORS to the storefront's own origins is the enforcement point for that —
 * there is no per-customer auth on a guest storefront, so origin allowlisting
 * plus rate limiting is the realistic security boundary here.
 */
export const shopCors = cors({
  origin(origin, callback) {
    if (!origin || config.allowedShopOrigins.includes(origin)) {
      callback(null, true);
      return;
    }
    callback(new ApiError(403, `Origin not allowed: ${origin}`));
  },
  methods: ['GET', 'POST', 'DELETE'],
});
