import {
  Body,
  Controller,
  Post,
  Get,
  Param,
  Query,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiParam,
  ApiQuery,
} from '@nestjs/swagger';
import { TelemetryService } from './telemetry.service';
import { TelemetryGateway } from './telemetry.gateway';
import {
  SaveTelemetryDto,
  TelemetryResponseDto,
  GetTelemetryQueryDto,
} from './dto';

/**
 * Controller for telemetry ingestion and retrieval endpoints.
 */
@ApiTags('Telemetry')
@Controller('events')
export class TelemetryController {
  constructor(
    private readonly telemetryService: TelemetryService,
    private readonly telemetryGateway: TelemetryGateway,
  ) {}

  @Post('telemetry')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary: 'Ingest telemetry data',
    description:
      'Saves telemetry data from a device. Implements idempotency using messageId to prevent duplicate records.',
  })
  @ApiResponse({
    status: HttpStatus.CREATED,
    description: 'Telemetry data successfully saved',
    type: TelemetryResponseDto,
  })
  @ApiResponse({
    status: HttpStatus.BAD_REQUEST,
    description: 'Invalid telemetry data',
  })
  async ingest(@Body() body: SaveTelemetryDto): Promise<TelemetryResponseDto> {
    const saved = await this.telemetryService.saveTelemetry(body);

    this.telemetryGateway.broadcastTelemetry(body.deviceId, saved);

    return saved;
  }

  @Get('telemetry')
  @ApiOperation({
    summary: 'Get all telemetry records',
    description:
      'Retrieves the most recent telemetry records across all devices, ordered by server timestamp (newest first).',
  })
  @ApiQuery({
    name: 'limit',
    required: false,
    description: 'Maximum number of records to return (1-1000)',
    example: 50,
    type: Number,
  })
  @ApiResponse({
    status: HttpStatus.OK,
    description: 'List of telemetry records from all devices',
    type: [TelemetryResponseDto],
  })
  async getAllTelemetry(
    @Query() query: GetTelemetryQueryDto,
  ): Promise<TelemetryResponseDto[]> {
    return this.telemetryService.getAllTelemetry(query.limit || 50);
  }

  @Get('devices/:deviceId/telemetry')
  @ApiOperation({
    summary: 'Get latest telemetry for a device',
    description:
      'Retrieves the most recent telemetry records for a specific device, ordered by server timestamp (newest first).',
  })
  @ApiParam({
    name: 'deviceId',
    description: 'Device identifier',
    example: 'mock-001',
  })
  @ApiQuery({
    name: 'limit',
    required: false,
    description: 'Maximum number of records to return (1-1000)',
    example: 50,
    type: Number,
  })
  @ApiResponse({
    status: HttpStatus.OK,
    description: 'List of telemetry records',
    type: [TelemetryResponseDto],
  })
  async getForDevice(
    @Param('deviceId') deviceId: string,
    @Query() query: GetTelemetryQueryDto,
  ): Promise<TelemetryResponseDto[]> {
    return this.telemetryService.getLatestByDevice(deviceId, query.limit || 50);
  }
}
