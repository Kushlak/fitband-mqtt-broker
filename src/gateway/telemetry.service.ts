import { Injectable, Logger } from '@nestjs/common';
import { prisma } from '../lib/prisma';
import {
  SaveTelemetryDto,
  TelemetryResponseDto,
  DeviceResponseDto,
  SessionResponseDto,
} from './dto';

/**
 * Service for managing telemetry data, devices, and sessions.
 * Handles telemetry ingestion, device lookup, and session management.
 */
@Injectable()
export class TelemetryService {
  private readonly logger = new Logger(TelemetryService.name);

  /**
   * Find a device by its identifier.
   *
   * @param deviceId - Device identifier
   * @returns Device record or null if not found
   */
  async findDeviceById(deviceId: string): Promise<DeviceResponseDto | null> {
    return prisma.device.findUnique({
      where: { id: deviceId },
    });
  }

  /**
   * Find an existing device or return null.
   * Note: Device creation should be handled through proper API endpoints.
   *
   * @param deviceId - Device identifier
   * @returns Device record or null if not found
   */
  async findOrCreateDevice(
    deviceId: string,
  ): Promise<DeviceResponseDto | null> {
    const device = await prisma.device.findUnique({
      where: { id: deviceId },
    });

    if (!device) {
      this.logger.warn(`Device not found: ${deviceId}`);
    }

    return device;
  }

  /**
   * Find the active session for a device.
   * An active session is one where endedAt is null.
   *
   * @param deviceId - Device identifier
   * @returns Active session record or null if no active session exists
   */
  async findActiveSession(
    deviceId: string,
  ): Promise<SessionResponseDto | null> {
    return prisma.session.findFirst({
      where: {
        deviceId,
        endedAt: null, // Active session
      },
      orderBy: {
        startedAt: 'desc',
      },
    });
  }

  /**
   * Save telemetry data to the database.
   * Implements idempotency using messageId to prevent duplicate records.
   * Automatically links telemetry to active session if one exists.
   *
   * @param input - Telemetry data DTO (tsDevice can be string or Date)
   * @returns Saved telemetry record
   */
  async saveTelemetry(input: SaveTelemetryDto): Promise<TelemetryResponseDto> {
    const { deviceId, messageId, tsDevice, ...metrics } = input;

    // Convert tsDevice string to Date if needed
    const tsDeviceDate =
      typeof tsDevice === 'string' ? new Date(tsDevice) : tsDevice;

    // Find active session for this device to link telemetry
    const activeSession = await this.findActiveSession(deviceId);

    // Check for existing telemetry with same messageId (idempotency)
    const existing = await prisma.telemetry.findUnique({
      where: {
        deviceId_messageId: {
          deviceId,
          messageId,
        },
      },
    });

    if (existing) {
      this.logger.debug(
        `Telemetry with messageId ${messageId} already exists for device ${deviceId}, returning existing record`,
      );
      return this.mapTelemetryToResponse(existing);
    }

    // Create new telemetry record
    const telemetry = await prisma.telemetry.create({
      data: {
        deviceId,
        sessionId: activeSession?.id || null,
        tsDevice: tsDeviceDate,
        tsServer: new Date(),
        heartRate: metrics.heartRate,
        stepsDelta: metrics.stepsDelta,
        caloriesDelta: metrics.caloriesDelta,
        battery: metrics.battery,
        ax: metrics.ax,
        ay: metrics.ay,
        az: metrics.az,
        messageId,
      },
    });

    this.logger.debug(
      `Saved telemetry for device ${deviceId} with messageId ${messageId}`,
    );

    // Convert Prisma Decimal types to numbers for response
    return this.mapTelemetryToResponse(telemetry);
  }

  /**
   * Get latest telemetry records across all devices.
   *
   * @param limit - Maximum number of records to return (default: 50, max: 1000)
   * @returns Array of telemetry records, ordered by server timestamp (newest first)
   */
  async getAllTelemetry(limit: number = 50): Promise<TelemetryResponseDto[]> {
    const safeLimit = Math.min(Math.max(1, limit), 1000);

    const telemetryRecords = await prisma.telemetry.findMany({
      orderBy: { tsServer: 'desc' },
      take: safeLimit,
    });

    return telemetryRecords.map((record) =>
      this.mapTelemetryToResponse(record),
    );
  }

  /**
   * Get latest telemetry records for a specific device.
   *
   * @param deviceId - Device identifier
   * @param limit - Maximum number of records to return (default: 50, max: 1000)
   * @returns Array of telemetry records, ordered by server timestamp (newest first)
   */
  async getLatestByDevice(
    deviceId: string,
    limit: number = 50,
  ): Promise<TelemetryResponseDto[]> {
    const safeLimit = Math.min(Math.max(1, limit), 1000);

    const telemetryRecords = await prisma.telemetry.findMany({
      where: { deviceId },
      orderBy: { tsServer: 'desc' },
      take: safeLimit,
    });

    return telemetryRecords.map((record) =>
      this.mapTelemetryToResponse(record),
    );
  }

  /**
   * Map Prisma telemetry record to response DTO, converting Decimal and BigInt types.
   *
   * @param record - Prisma telemetry record
   * @returns Telemetry response DTO
   */
  private mapTelemetryToResponse(record: any): TelemetryResponseDto {
    return {
      ...record,
      id: record.id ? record.id.toString() : record.id, // Convert BigInt to string
      caloriesDelta: record.caloriesDelta ? Number(record.caloriesDelta) : null,
      battery: record.battery ? Number(record.battery) : null,
      ax: record.ax ? Number(record.ax) : null,
      ay: record.ay ? Number(record.ay) : null,
      az: record.az ? Number(record.az) : null,
    };
  }
}
