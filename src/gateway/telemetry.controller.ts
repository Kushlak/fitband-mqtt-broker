// src/gateway/telemetry.controller.ts
import { Body, Controller, Post, Get, Param, Query } from '@nestjs/common';
import { TelemetryService } from './telemetry.service';
import { TelemetryGateway } from './telemetry.gateway';

class TelemetryDto {
  deviceId: string;
  messageId: string;
  tsDevice: string;
  heartRate: number;
  stepsDelta: number;
  battery: number;
}

@Controller('events')
export class TelemetryController {
  constructor(
    private readonly telemetryService: TelemetryService,
    private readonly telemetryGateway: TelemetryGateway,
  ) {}

  @Post('telemetry')
  async ingest(@Body() body: TelemetryDto) {
    const { tsDevice, ...rest } = body;

    const saved = await this.telemetryService.saveTelemetry({
      ...rest,
      tsDevice: new Date(tsDevice),
    });

    // Одразу розсилаємо по WebSocket усім, хто підписаний на цей девайс:
    this.telemetryGateway.broadcastTelemetry(body.deviceId, saved);

    return saved;
  }

  @Get('devices/:deviceId/telemetry')
  async getForDevice(
    @Param('deviceId') deviceId: string,
    @Query('limit') limit = '50',
  ) {
    return this.telemetryService.getLatestByDevice(deviceId, Number(limit));
  }
}
