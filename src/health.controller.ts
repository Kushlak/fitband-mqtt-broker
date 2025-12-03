import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  basic() {
    return { status: 'ok' };
  }

  @Get('liveness')
  liveness() {
    return { status: 'alive' };
  }

  @Get('readiness')
  readiness() {
    return { status: 'ready' };
  }
}
