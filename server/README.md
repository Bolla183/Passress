# Passress Try-On API

Backend for the Passress AI Virtual Try-On feature. It accepts a customer
photo and product info from the Shopify theme, renders a try-on image
through a swappable AI provider, and exposes job creation, polling, and
result endpoints. The theme never talks to storage, the queue, or an AI
provider directly — only to this API.

## Architecture

```
Shopify theme (virtual-tryon.js)
        │  multipart POST (photo + product info)
        ▼
   API (src/index.ts)
        │  validates + sanitizes upload, writes source photo to storage,
        │  creates a TryOnJob row, enqueues a render job
        ▼
  Postgres (job metadata)      Redis / BullMQ (queue)
                                       │
                                       ▼
                              Worker (src/worker.ts)
                                       │  fetches source photo, calls the
                                       │  configured TryOnProvider, writes
                                       │  the result to storage
                                       ▼
                              Object storage (S3-compatible)
```

The theme polls `GET /v1/tryon/jobs/:id` until `status` is `succeeded` (or
`failed`), then loads the result from `resultUrl` — a short-lived signed URL,
never a public bucket path.

## API contract

All endpoints are under `/v1/tryon/jobs`. CORS is restricted to
`ALLOWED_SHOP_ORIGINS` — there is no per-customer auth, since storefront
visitors are unauthenticated guests; origin allowlisting plus per-IP rate
limiting is the realistic security boundary for a public upload endpoint.

### `POST /v1/tryon/jobs`
`multipart/form-data`:
| field | required | notes |
|---|---|---|
| `photo` | yes | image file, ≤ `MAX_UPLOAD_BYTES`, sniffed by content not by client-supplied mimetype |
| `shopDomain` | yes | e.g. `passress.myshopify.com` |
| `productId` | yes | Shopify product GID |
| `productTitle` | yes | shown in loading/result copy |
| `variantId` | no | Shopify variant GID |
| `colorName` | no | selected colorway |
| `garmentImageUrl` | no | reference product photo for the provider to draw on |

Rate limited to `RATE_LIMIT_MAX_JOBS_PER_WINDOW` per IP per
`RATE_LIMIT_WINDOW_MINUTES`.

→ `201 { jobId, status: "queued", createdAt, expiresAt, pollUrl }`

### `GET /v1/tryon/jobs/:id`
→ `200 { jobId, status, progress, resultUrl, error, createdAt, updatedAt, expiresAt }`

`status` is one of `queued | processing | succeeded | failed`. `resultUrl` is
only populated once `succeeded`; it's a signed URL valid for
`STORAGE_SIGNED_URL_TTL_SECONDS`.

### `GET /v1/tryon/jobs/:id/result`
Convenience redirect: `302` to the signed result URL once ready, `202` while
still processing, `409` if the job failed. Usable directly as an `<img src>`
once you know the job succeeded.

### `DELETE /v1/tryon/jobs/:id`
Deletes the job row and both stored images immediately. `204`. Jobs also
expire and get swept automatically after `JOB_TTL_HOURS` — this backs the
frontend's promise that a customer's photo isn't stored or shared beyond the
preview session.

## Swapping in a real AI provider

Everything about "how the try-on image actually gets made" is isolated
behind one interface:

```ts
// src/providers/tryon-provider.ts
interface TryOnProvider {
  readonly name: string;
  render(input: TryOnRenderInput): Promise<TryOnRenderResult>;
}
```

`src/providers/mock-provider.ts` is today's only implementation — it
generates a placeholder card server-side (mirroring the frontend's Phase 2
mock) so the whole queue → worker → storage → status pipeline can be
exercised for free, with no AI cost.

To connect a real provider:
1. Add `src/providers/<name>-provider.ts` implementing `TryOnProvider`.
2. Add one `case` for it in `src/providers/provider-factory.ts`.
3. Set `TRYON_PROVIDER=<name>` (plus whatever env vars that provider needs).

Nothing else changes — not the worker, not the routes, not the job model,
and not the Shopify theme, which only ever sees `queued/processing/succeeded/failed`
and a `resultUrl`.

## Security notes

- Uploads are sniffed by actual file content (`file-type`), not the
  client-supplied `Content-Type` header.
- Every accepted photo is re-encoded through `sharp`, which strips
  EXIF/GPS metadata and normalizes orientation before it's ever written to
  storage.
- Result images are only ever served via short-lived signed URLs; the
  bucket itself should be private.
- CORS is restricted to `ALLOWED_SHOP_ORIGINS`; job creation is rate
  limited per IP.
- Jobs (and their photos) auto-expire after `JOB_TTL_HOURS` via a
  repeatable cleanup job.
- Job IDs are UUIDv4 and act as the only "credential" to poll or delete a
  job — appropriate for a guest storefront preview flow, not for anything
  more sensitive.

## Local development

```bash
cp .env.example .env
docker compose up -d postgres redis minio minio-init
npm install
npm run prisma:migrate
npm run dev:api     # terminal 1
npm run dev:worker  # terminal 2
```

`docker compose up --build api worker` runs the containerized version end
to end instead.

## Deploying

- `npm run build && npm run start:api` / `npm run start:worker`, or the
  provided `Dockerfile` (same image, different `CMD`, for the API vs. the
  worker).
- Point `DATABASE_URL` at a real Postgres instance, `REDIS_URL` at a real
  Redis instance, and `STORAGE_*` at any S3-compatible bucket (AWS S3,
  Cloudflare R2, DigitalOcean Spaces all work — only the endpoint changes).
- The API and worker are independently horizontally scalable; the queue is
  the point that absorbs load spikes so slow AI calls never block the HTTP
  request/response cycle.
