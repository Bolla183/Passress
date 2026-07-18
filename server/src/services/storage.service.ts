import {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { config } from '../config';

const client = new S3Client({
  endpoint: config.storage.endpoint || undefined,
  region: config.storage.region,
  forcePathStyle: config.storage.forcePathStyle,
  credentials: {
    accessKeyId: config.storage.accessKeyId,
    secretAccessKey: config.storage.secretAccessKey,
  },
});

/**
 * Thin wrapper around the S3 API surface actually used by this service.
 * Any S3-compatible provider (AWS S3, Cloudflare R2, DigitalOcean Spaces,
 * MinIO for local dev) works by pointing STORAGE_ENDPOINT at it — nothing
 * in the rest of the codebase depends on a specific provider.
 */
export const storageService = {
  async putObject(key: string, body: Buffer, contentType: string): Promise<void> {
    await client.send(
      new PutObjectCommand({
        Bucket: config.storage.bucket,
        Key: key,
        Body: body,
        ContentType: contentType,
      }),
    );
  },

  async getObjectBuffer(key: string): Promise<Buffer> {
    const response = await client.send(
      new GetObjectCommand({ Bucket: config.storage.bucket, Key: key }),
    );
    const chunks: Buffer[] = [];
    for await (const chunk of response.Body as AsyncIterable<Buffer>) {
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    }
    return Buffer.concat(chunks);
  },

  async getSignedDownloadUrl(key: string): Promise<string> {
    const command = new GetObjectCommand({ Bucket: config.storage.bucket, Key: key });
    return getSignedUrl(client, command, { expiresIn: config.storage.signedUrlTtlSeconds });
  },

  async deleteObject(key: string): Promise<void> {
    await client.send(new DeleteObjectCommand({ Bucket: config.storage.bucket, Key: key }));
  },
};
