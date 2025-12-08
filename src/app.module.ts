import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { ConfigModule } from '@nestjs/config';
import { EventsController } from './events/events.controller';
import { EventsService } from './events/events.service';
import { HealthController } from './health.controller';
import { TelemetryGateway } from './gateway/telemetry.gateway';
import { ApiKeyGuard } from './common/guards/api-key.guard';
import { TelemetryService } from './gateway/telemetry.service';
import { TelemetryController } from './gateway/telemetry.controller';
import { CommonModule } from './common/common.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    CommonModule
  ],
  controllers: [
    AppController,
    EventsController,
    HealthController,
    TelemetryController,
  ],
  providers: [
    AppService,
    TelemetryGateway,
    TelemetryService,
    EventsService,
    ApiKeyGuard,
  ],
})
export class AppModule {}
