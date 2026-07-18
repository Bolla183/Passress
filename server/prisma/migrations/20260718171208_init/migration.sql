-- CreateEnum
CREATE TYPE "TryOnJobStatus" AS ENUM ('queued', 'processing', 'succeeded', 'failed');

-- CreateTable
CREATE TABLE "TryOnJob" (
    "id" TEXT NOT NULL,
    "shopDomain" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "variantId" TEXT,
    "productTitle" TEXT NOT NULL,
    "colorName" TEXT,
    "garmentImageUrl" TEXT,
    "status" "TryOnJobStatus" NOT NULL DEFAULT 'queued',
    "provider" TEXT,
    "sourceImageKey" TEXT NOT NULL,
    "resultImageKey" TEXT,
    "errorMessage" TEXT,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TryOnJob_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "TryOnJob_shopDomain_createdAt_idx" ON "TryOnJob"("shopDomain", "createdAt");

-- CreateIndex
CREATE INDEX "TryOnJob_status_idx" ON "TryOnJob"("status");

-- CreateIndex
CREATE INDEX "TryOnJob_expiresAt_idx" ON "TryOnJob"("expiresAt");
