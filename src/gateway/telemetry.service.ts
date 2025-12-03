// src/gateway/telemetry.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../common/Prisma.Service';

@Injectable()
export class TelemetryService {
  private readonly logger = new Logger(TelemetryService.name);

  constructor(private readonly prisma: PrismaService) {}

  async findDeviceById(deviceId: string) {
    return this.prisma.device.findUnique({
      where: { id: deviceId },
    });
  }

  async findOrCreateDevice(deviceId: string) {
    let device = await this.prisma.device.findUnique({
      where: { id: deviceId },
    });

    if (!device) {
      // Device must be created via API first (requires userId)
      // For simulator/testing, we'll try to find or create a user
      // In production, this should be handled through proper device registration API
      let user = await this.prisma.user.findUnique({
        where: { deviceId },
      });

      if (!user) {
        // Create a minimal user for the device
        // This is a workaround for simulator - in production, users should be created via auth API
        // Note: User.deviceId should match Device.id
        user = await this.prisma.user.create({
          data: {
            email: `device-${deviceId}@simulator.local`,
            password: 'simulator-password', // Not used for WebSocket connections
            deviceId: deviceId, // This references Device.id
          },
        });
        this.logger.log(`Created user for device: ${deviceId}`);
      }

      // Create device with id = deviceId and userId = user.id
      device = await this.prisma.device.create({
        data: {
          id: deviceId, // Set explicitly to match simulator's deviceId
          name: `Device ${deviceId}`,
          secret: `secret-${deviceId}`, // Should be properly generated in production
          userId: user.id, // Reference to User.id (UUID)
        },
      });
      this.logger.log(`Created new device: ${deviceId}`);
    }

    return device;
  }

  async findActiveSession(deviceId: string) {
    return this.prisma.session.findFirst({
      where: {
        deviceId,
        endedAt: null, // Active session
      },
      orderBy: {
        startedAt: 'desc',
      },
    });
  }

  async saveTelemetry(input: {
    deviceId: string;
    messageId: string;
    tsDevice: Date;
    heartRate: number;
    stepsDelta: number;
    caloriesDelta: number;
    battery: number;
    ax?: number;
    ay?: number;
    az?: number;
  }) {
    const { deviceId, ...rest } = input;

    // Find active session for this device
    const activeSession = await this.findActiveSession(deviceId);

    // Use idempotency: check if messageId already exists for this device
    const existing = await this.prisma.telemetry.findUnique({
      where: {
        deviceId_messageId: {
          deviceId,
          messageId: input.messageId,
        },
      },
    });

    if (existing) {
      this.logger.debug(
        `Telemetry with messageId ${input.messageId} already exists, skipping`,
      );
      return existing;
    }

    return this.prisma.telemetry.create({
      data: {
        deviceId,
        sessionId: activeSession?.id || null,
        tsDevice: input.tsDevice,
        tsServer: new Date(),
        heartRate: input.heartRate,
        stepsDelta: input.stepsDelta,
        caloriesDelta: input.caloriesDelta,
        battery: input.battery,
        ax: input.ax,
        ay: input.ay,
        az: input.az,
        messageId: input.messageId,
      },
    });
  }

  async getLatestByDevice(deviceId: string, limit = 50) {
    return this.prisma.telemetry.findMany({
      where: { deviceId },
      orderBy: { tsServer: 'desc' },
      take: limit,
    });
  }
}
