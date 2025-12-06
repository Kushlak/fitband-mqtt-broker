// src/gateway/telemetry.gateway.ts
import {
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { TelemetryService } from './telemetry.service';
import { HmacUtil } from '../common/utils/hmac.util';

interface JoinPayload {
  deviceId: string;
  timestamp: string;
  signature: string;
}

interface TelemetryPayload {
  deviceId: string;
  timestamp: string;
  messageId: string;
  metrics: {
    heartRate: number;
    stepsDelta: number;
    caloriesDelta: number;
    battery: number;
  };
  motion?: {
    ax?: number;
    ay?: number;
    az?: number;
  };
  signature?: string; // Optional HMAC signature for telemetry
}

interface CommandPayload {
  deviceId: string;
  command: string;
  payload?: any;
}

@Injectable()
@WebSocketGateway({
  path: '/ws',
  cors: {
    origin: (process.env.CORS_ORIGIN || '*')
      .split(',')
      .map((o) => o.trim())
      .filter(Boolean),
    credentials: true,
  },
})
export class TelemetryGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(TelemetryGateway.name);
  private deviceConnections = new Map<string, Set<string>>(); // deviceId -> Set of socket IDs

  constructor(private readonly telemetryService: TelemetryService) {}

  handleConnection(client: Socket) {
    this.logger.log(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    this.logger.log(`Client disconnected: ${client.id}`);
    const deviceId = client.data.deviceId;

    // Clean up device connections
    if (deviceId && this.deviceConnections.has(deviceId)) {
      const socketIds = this.deviceConnections.get(deviceId)!;
      socketIds.delete(client.id);

      // If this was the last socket for this device, emit device:disconnected
      if (socketIds.size === 0) {
        this.deviceConnections.delete(deviceId);
        this.server.emit('device:disconnected', {
          deviceId,
          disconnectedAt: new Date().toISOString(),
        });
        this.logger.log(`Device ${deviceId} fully disconnected`);
      } else {
        this.logger.log(
          `Device ${deviceId} socket disconnected (${socketIds.size} remaining)`,
        );
      }
    }
  }

  @SubscribeMessage('join')
  async handleJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: JoinPayload | string,
  ) {
    // Support both object payload (with HMAC) and string (deviceId only, for backward compatibility)
    let deviceId: string;
    let timestamp: string;
    let signature: string | undefined;

    if (typeof payload === 'string') {
      // Backward compatibility: just deviceId
      deviceId = payload;
      timestamp = new Date().toISOString();
      signature = undefined;
      this.logger.warn(
        `Join event without HMAC signature from ${client.id} - using deviceId only`,
      );
    } else {
      deviceId = payload.deviceId;
      timestamp = payload.timestamp;
      signature = payload.signature;
    }

    if (!deviceId || typeof deviceId !== 'string') {
      this.logger.warn(`Invalid deviceId in join event from ${client.id}`);
      client.emit('error', { message: 'Invalid deviceId' });
      return;
    }

    // Find or create device (supports mock simulator without pre-registration)
    const device = await this.telemetryService.findOrCreateDevice(deviceId);

    if (!device) {
      this.logger.error(`Failed to find or create device: ${deviceId}`);
      client.emit('error', { message: 'Failed to register device' });
      return;
    }

    // Verify HMAC signature if provided
    if (signature) {
      const isValid = HmacUtil.verifyJoin(
        deviceId,
        timestamp,
        device.secret,
        signature,
      );

      if (!isValid) {
        this.logger.warn(
          `Invalid HMAC signature for device ${deviceId} from ${client.id}`,
        );
        client.emit('error', { message: 'Invalid signature' });
        return;
      }
    } else {
      // If no signature provided, log warning but allow (for development/testing)
      this.logger.warn(
        `Join event without HMAC signature for device ${deviceId} - allowing for development`,
      );
    }

    // Check if this is a new device connection (first socket for this device)
    const isNewDevice = !this.deviceConnections.has(deviceId);

    // Register device connection
    if (!this.deviceConnections.has(deviceId)) {
      this.deviceConnections.set(deviceId, new Set());
    }
    this.deviceConnections.get(deviceId)!.add(client.id);

    // Store device info in socket data
    client.data.deviceId = deviceId;
    client.data.deviceSecret = device.secret;
    client.data.authenticated = true;

    this.logger.log(`Device ${deviceId} joined and authenticated (socket ${client.id})`);

    client.emit('joined', { deviceId, authenticated: true });

    // Emit device:connected event to all frontend clients if this is a new device
    if (isNewDevice) {
      this.server.emit('device:connected', {
        deviceId,
        deviceName: device.name,
        connectedAt: new Date().toISOString(),
        socketCount: this.deviceConnections.get(deviceId)!.size,
      });
    }
  }

  @SubscribeMessage('telemetry')
  async handleTelemetry(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: TelemetryPayload,
  ) {
    // Check if client is authenticated
    if (!client.data.authenticated) {
      this.logger.warn(
        `Telemetry received from unauthenticated client ${client.id}`,
      );
      client.emit('error', { message: 'Not authenticated' });
      return;
    }

    const deviceId = client.data.deviceId || data.deviceId;
    const deviceSecret = client.data.deviceSecret;

    if (!deviceId) {
      this.logger.warn(`Telemetry received without deviceId from ${client.id}`);
      client.emit('error', { message: 'Device ID missing' });
      return;
    }

    // Verify HMAC signature if provided (optional for telemetry, but recommended)
    if (data.signature && deviceSecret) {
      // Create payload string for signature verification
      // Exclude signature from the payload being verified
      const { signature, ...payloadForSigning } = data;
      const payloadString = JSON.stringify(payloadForSigning);

      const isValid = HmacUtil.verifyTelemetry(
        payloadString,
        deviceSecret,
        signature,
      );

      if (!isValid) {
        this.logger.warn(
          `Invalid HMAC signature for telemetry from device ${deviceId}`,
        );
        client.emit('error', { message: 'Invalid telemetry signature' });
        return;
      }
    }

    try {
      // Save telemetry to database
      const saved = await this.telemetryService.saveTelemetry({
        deviceId,
        messageId: data.messageId,
        tsDevice: new Date(data.timestamp),
        heartRate: data.metrics.heartRate,
        stepsDelta: data.metrics.stepsDelta,
        caloriesDelta: data.metrics.caloriesDelta,
        battery: data.metrics.battery,
        ax: data.motion?.ax,
        ay: data.motion?.ay,
        az: data.motion?.az,
      });

      this.logger.debug(
        `Saved telemetry for device ${deviceId}: messageId=${data.messageId}`,
      );

      // Broadcast to subscribed clients (if needed)
      this.broadcastTelemetry(deviceId, saved);

      // Emit telemetry event to all frontend clients
      this.server.emit('telemetry:new', {
        deviceId,
        telemetry: saved,
        receivedAt: new Date().toISOString(),
      });
    } catch (error: any) {
      this.logger.error(
        `Error saving telemetry for device ${deviceId}: ${error.message}`,
      );
      client.emit('error', { message: 'Failed to save telemetry' });
    }
  }

  @SubscribeMessage('subscribe:device')
  handleSubscribeDevice(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { deviceId: string },
  ) {
    const room = `device:${data.deviceId}`;
    client.join(room);
    this.logger.log(`Client ${client.id} subscribed to ${room}`);
    client.emit('subscribed', { room });
  }

  @SubscribeMessage('get:connected-devices')
  handleGetConnectedDevices(@ConnectedSocket() client: Socket) {
    const devices = Array.from(this.deviceConnections.keys()).map((deviceId) => ({
      deviceId,
      socketCount: this.deviceConnections.get(deviceId)!.size,
    }));

    client.emit('connected-devices', { devices });
  }

  @SubscribeMessage('unsubscribe:device')
  handleUnsubscribeDevice(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { deviceId: string },
  ) {
    const room = `device:${data.deviceId}`;
    client.leave(room);
    this.logger.log(`Client ${client.id} unsubscribed from ${room}`);
    client.emit('unsubscribed', { room });
  }

  @SubscribeMessage('command')
  handleClientCommand(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: CommandPayload,
  ) {
    this.logger.log(
      `Received command from client ${client.id} for device ${data.deviceId}: ${data.command}`,
    );
  }

  broadcastTelemetry(deviceId: string, telemetry: any) {
    const room = `device:${deviceId}`;
    this.logger.debug(
      `Broadcast telemetry to ${room}: ${JSON.stringify(telemetry)}`,
    );
    this.server.to(room).emit('telemetry', { deviceId, telemetry });
  }

  broadcastCommandToClients(deviceId: string, command: any) {
    const room = `device:${deviceId}`;
    this.logger.debug(
      `Broadcast command to clients in ${room}: ${JSON.stringify(command)}`,
    );
    this.server.to(room).emit('command', { deviceId, ...command });
  }
}
