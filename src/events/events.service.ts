import { Injectable, Logger } from '@nestjs/common';
import { TelemetryGateway } from '../gateway/telemetry.gateway';
import { TelemetryEventDto } from './dto/telemetry-event.dto';
import { CommandEventDto } from './dto/command-event.dto';

@Injectable()
export class EventsService {
  private readonly logger = new Logger(EventsService.name);

  constructor(private readonly telemetryGateway: TelemetryGateway) {}

  handleTelemetry(event: TelemetryEventDto) {
    this.logger.log(
      `Received telemetry for device ${event.deviceId}: ${JSON.stringify(
        event.telemetry,
      )}`,
    );
    this.telemetryGateway.broadcastTelemetry(event.deviceId, event.telemetry);
  }

  handleCommand(event: CommandEventDto) {
    this.logger.log(
      `Received command for device ${event.deviceId}: ${event.command}`,
    );
    this.telemetryGateway.broadcastCommandToClients(event.deviceId, {
      command: event.command,
      payload: event.payload,
    });
  }
}
