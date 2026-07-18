import sharp from 'sharp';
import { hexForColor } from '../utils/color';
import type { TryOnProvider, TryOnRenderInput, TryOnRenderResult } from './tryon-provider';

const WIDTH = 900;
const HEIGHT = 1200;

function escapeXml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function buildPlaceholderSvg(productTitle: string, colorName?: string): string {
  const accent = hexForColor(colorName);
  const title = escapeXml(productTitle || 'Passress');
  const subtitle = colorName ? escapeXml(colorName) : '';

  return `
    <svg width="${WIDTH}" height="${HEIGHT}" viewBox="0 0 ${WIDTH} ${HEIGHT}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="wash" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="${accent}" stop-opacity="0.16"/>
          <stop offset="100%" stop-color="#e7e3d8" stop-opacity="1"/>
        </linearGradient>
      </defs>
      <rect width="${WIDTH}" height="${HEIGHT}" fill="#f4f3ef"/>
      <rect width="${WIDTH}" height="${HEIGHT}" fill="url(#wash)"/>
      <text x="50%" y="46%" text-anchor="middle" font-family="Helvetica, Arial, sans-serif"
            font-size="24" font-weight="600" letter-spacing="4" fill="rgba(17,17,17,0.55)">AI PREVIEW</text>
      <text x="50%" y="52%" text-anchor="middle" font-family="Helvetica, Arial, sans-serif"
            font-size="40" font-weight="500" fill="#111111">${title}</text>
      ${subtitle ? `<text x="50%" y="57%" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-size="20" fill="#767676">${subtitle}</text>` : ''}
      <rect x="0" y="${HEIGHT - 64}" width="${WIDTH}" height="64" fill="rgba(17,17,17,0.7)"/>
      <text x="28" y="${HEIGHT - 24}" font-family="Helvetica, Arial, sans-serif" font-size="22" font-weight="600" fill="#ffffff">PASSRESS</text>
    </svg>
  `;
}

/**
 * Generates a placeholder image server-side, mirroring the frontend's
 * mock result screen. Used for local development and for exercising the
 * full queue -> worker -> storage -> status pipeline without spending
 * money on a real AI provider. Swap TRYON_PROVIDER to move past this.
 */
export class MockProvider implements TryOnProvider {
  readonly name = 'mock';

  async render(input: TryOnRenderInput): Promise<TryOnRenderResult> {
    // Simulate realistic render latency so the queued -> processing ->
    // succeeded state machine and any progress UI can be exercised for real.
    await new Promise((resolve) => setTimeout(resolve, 1500));

    const svg = buildPlaceholderSvg(input.productTitle, input.colorName);
    const resultBuffer = await sharp(Buffer.from(svg)).png().toBuffer();

    return {
      resultBuffer,
      contentType: 'image/png',
      meta: { provider: this.name, mocked: true },
    };
  }
}
