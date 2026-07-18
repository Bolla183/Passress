import sharp from 'sharp';

const ALLOWED_MIME_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);
const MAX_DIMENSION = 2000;

export class InvalidImageError extends Error {}

export interface SanitizedImage {
  buffer: Buffer;
  contentType: 'image/jpeg';
}

/**
 * Validates an uploaded photo by its actual content (not the client-supplied
 * mimetype, which is trivially spoofable) and re-encodes it. Re-encoding via
 * sharp strips EXIF/GPS metadata and normalizes orientation, so nothing about
 * where or how the photo was taken is retained in storage.
 */
export async function sanitizeUploadedImage(raw: Buffer): Promise<SanitizedImage> {
  // file-type is ESM-only; dynamic import is the supported way to consume
  // it from this CommonJS codebase.
  const { fileTypeFromBuffer } = await import('file-type');
  const detected = await fileTypeFromBuffer(raw);
  if (!detected || !ALLOWED_MIME_TYPES.has(detected.mime)) {
    throw new InvalidImageError('Unsupported or unrecognized image format.');
  }

  const buffer = await sharp(raw)
    .rotate()
    .resize({ width: MAX_DIMENSION, height: MAX_DIMENSION, fit: 'inside', withoutEnlargement: true })
    .jpeg({ quality: 90 })
    .toBuffer();

  return { buffer, contentType: 'image/jpeg' };
}
