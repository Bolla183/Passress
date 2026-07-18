/**
 * file-type ships ESM-only with a moduleResolution scheme this CommonJS
 * project doesn't use, so this project can't resolve its published types.
 * We only need the one function we actually call — declared minimally here
 * so the dynamic import() in upload.service.ts type-checks.
 */
declare module 'file-type' {
  export interface FileTypeResult {
    ext: string;
    mime: string;
  }

  export function fileTypeFromBuffer(input: Uint8Array | ArrayBuffer): Promise<FileTypeResult | undefined>;
}
