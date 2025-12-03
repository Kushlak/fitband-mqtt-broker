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
import { Injectable, Logger } from '@nestjs/common';
import { Server, Socket } from 'socket.io';

interface SubscribeDevicePayload {
  deviceId: string;
}

interface CommandPayload {
  deviceId: string;
  command: string;
  payload?: any;
}

@Injectable()
@WebSocketGateway({
  cors: {
    origin: (process.env.CORS_ORIGIN || '*')
      .split(',')
      .map((o) => o.trim())
      .filter(Boolean),
    credentials: true,
  },
  // path залишаємо дефолтний `/socket.io`
})
export class TelemetryGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(TelemetryGateway.name);

  handleConnection(client: Socket) {
    this.logger.log(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    this.logger.log(`Client disconnected: ${client.id}`);
  }

  @SubscribeMessage('subscribe:device')
  handleSubscribeDevice(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: SubscribeDevicePayload,
  ) {
    const room = `device:${data.deviceId}`;
    client.join(room);
    this.logger.log(`Client ${client.id} subscribed to ${room}`);
    client.emit('subscribed', { room });
  }

  @SubscribeMessage('unsubscribe:device')
  handleUnsubscribeDevice(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: SubscribeDevicePayload,
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
