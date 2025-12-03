-- CreateTable
CREATE TABLE "Device" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "secret" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Device_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Session" (
    "id" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endedAt" TIMESTAMP(3),
    "notes" TEXT,

    CONSTRAINT "Session_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Telemetry" (
    "id" BIGSERIAL NOT NULL,
    "deviceId" TEXT NOT NULL,
    "sessionId" TEXT,
    "tsDevice" TIMESTAMP(3) NOT NULL,
    "tsServer" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "heartRate" INTEGER,
    "stepsDelta" INTEGER,
    "caloriesDelta" DECIMAL(8,3),
    "battery" DECIMAL(4,3),
    "ax" DECIMAL(6,3),
    "ay" DECIMAL(6,3),
    "az" DECIMAL(6,3),
    "messageId" TEXT,

    CONSTRAINT "Telemetry_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Device_createdAt_idx" ON "Device"("createdAt" DESC);

-- CreateIndex
CREATE INDEX "Session_deviceId_startedAt_idx" ON "Session"("deviceId", "startedAt" DESC);

-- CreateIndex
CREATE INDEX "Telemetry_deviceId_tsServer_idx" ON "Telemetry"("deviceId", "tsServer" DESC);

-- CreateIndex
CREATE INDEX "Telemetry_sessionId_tsServer_idx" ON "Telemetry"("sessionId", "tsServer" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "Telemetry_deviceId_messageId_key" ON "Telemetry"("deviceId", "messageId");

-- AddForeignKey
ALTER TABLE "Session" ADD CONSTRAINT "Session_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Telemetry" ADD CONSTRAINT "Telemetry_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Telemetry" ADD CONSTRAINT "Telemetry_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "Session"("id") ON DELETE SET NULL ON UPDATE CASCADE;
