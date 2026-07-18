function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required env var: ${name}`);
  return value;
}

function optional(name: string, fallback: string): string {
  return process.env[name] ?? fallback;
}

export const config = {
  port: Number(optional('PORT', '8080')),
  nodeEnv: optional('NODE_ENV', 'development'),

  allowedShopOrigins: required('ALLOWED_SHOP_ORIGINS')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean),

  databaseUrl: required('DATABASE_URL'),
  redisUrl: required('REDIS_URL'),

  storage: {
    endpoint: optional('STORAGE_ENDPOINT', ''),
    region: optional('STORAGE_REGION', 'auto'),
    bucket: required('STORAGE_BUCKET'),
    accessKeyId: required('STORAGE_ACCESS_KEY_ID'),
    secretAccessKey: required('STORAGE_SECRET_ACCESS_KEY'),
    forcePathStyle: optional('STORAGE_FORCE_PATH_STYLE', 'false') === 'true',
    signedUrlTtlSeconds: Number(optional('STORAGE_SIGNED_URL_TTL_SECONDS', '900')),
  },

  jobTtlHours: Number(optional('JOB_TTL_HOURS', '24')),
  maxUploadBytes: Number(optional('MAX_UPLOAD_BYTES', String(8 * 1024 * 1024))),

  tryonProvider: optional('TRYON_PROVIDER', 'mock'),

  rateLimit: {
    windowMinutes: Number(optional('RATE_LIMIT_WINDOW_MINUTES', '10')),
    maxJobsPerWindow: Number(optional('RATE_LIMIT_MAX_JOBS_PER_WINDOW', '10')),
  },
} as const;
