// src/gateway/telemetry.service.ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/Prisma.Service';

@Injectable()
export class TelemetryService {
  constructor(private readonly prisma: PrismaService) {}

  async saveTelemetry(input: {
    deviceId: string;
    messageId: string;
    tsDevice: Date;
    heartRate: number;
    stepsDelta: number;
    battery: number;
  }) {
    const { deviceId, ...rest } = input;

    return this.prisma.telemetry.create({
      data: {
        deviceId,      // FK на Device
        tsServer: new Date(), // якщо є таке поле в моделі (і хочеш ще й явно ставити)
        ...rest,
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
