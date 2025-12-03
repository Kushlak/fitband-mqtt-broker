import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ConfigService } from '@nestjs/config';
import { ValidationPipe } from '@nestjs/common';
import helmet from 'helmet';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    cors: {
      origin: (process.env.CORS_ORIGIN || '*')
        .split(',')
        .map((o) => o.trim())
        .filter(Boolean),
      credentials: true,
    },
  });

  const configService = app.get(ConfigService);
  const port = configService.get<number>('HTTP_PORT') || 8080;

  app.use(helmet());
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  await app.listen(port);
  console.log(`WebSocket service listening on port ${port}`);
}
bootstrap();