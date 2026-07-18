export interface TryOnRenderInput {
  /** Raw bytes of the customer's cropped, EXIF-stripped photo. */
  sourcePhoto: Buffer;
  productTitle: string;
  colorName?: string;
  /** Reference photo of the garment, if one is available for the provider to draw on. */
  garmentImageUrl?: string;
}

export interface TryOnRenderResult {
  resultBuffer: Buffer;
  contentType: string;
  meta?: Record<string, unknown>;
}

/**
 * Everything the worker knows about "an AI virtual try-on provider."
 * Swapping providers means writing a new class that implements this
 * interface and registering it in provider-factory.ts — the worker,
 * routes, job model and frontend contract never change.
 */
export interface TryOnProvider {
  readonly name: string;
  render(input: TryOnRenderInput): Promise<TryOnRenderResult>;
}
