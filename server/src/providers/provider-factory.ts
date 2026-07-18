import { config } from '../config';
import { MockProvider } from './mock-provider';
import type { TryOnProvider } from './tryon-provider';

/**
 * The single place that decides which AI provider handles renders.
 *
 * To connect a real provider later:
 *   1. Add a new class in src/providers implementing TryOnProvider.
 *   2. Add a case below for it, reading whatever env vars it needs.
 *   3. Set TRYON_PROVIDER to its name.
 * Nothing else in the codebase — worker, routes, job model, or the
 * Shopify theme — needs to change.
 */
export function createTryOnProvider(): TryOnProvider {
  switch (config.tryonProvider) {
    case 'mock':
      return new MockProvider();
    default:
      throw new Error(`Unknown TRYON_PROVIDER "${config.tryonProvider}"`);
  }
}
