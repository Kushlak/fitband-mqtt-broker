import {
  Body,
  Controller,
  Post,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { EventsService } from './events.service';
import { TelemetryEventDto } from './dto/telemetry-event.dto';
import { CommandEventDto } from './dto/command-event.dto';
import { ApiKeyGuard } from '../common/guards/api-key.guard';

@Controller('events')
@UseGuards(ApiKeyGuard)
export class EventsController {
  constructor(private readonly eventsService: EventsService) {}

  @Post('telemetry')
  @HttpCode(HttpStatus.ACCEPTED)
  handleTelemetry(@Body() body: TelemetryEventDto) {
    this.eventsService.handleTelemetry(body);
    return { status: 'ok' };
  }

  @Post('command')
  @HttpCode(HttpStatus.ACCEPTED)
  handleCommand(@Body() body: CommandEventDto) {
    this.eventsService.handleCommand(body);
    return { status: 'ok' };
  }
}
