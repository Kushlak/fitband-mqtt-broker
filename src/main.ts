import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ConfigService } from '@nestjs/config';
import { ValidationPipe } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import helmet from 'helmet';
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import type { NestApplicationOptions } from '@nestjs/common';
import { ServerOptions } from 'http';

async function bootstrap() {
  const configService = new ConfigService();

  // HTTPS configuration
  const enableHttps = configService.get<string>('ENABLE_HTTPS') === 'true';
  const appOptions: NestApplicationOptions = {
    cors: {
      origin: true, // Allow all origins
      credentials: true,
    },
  };

  if (enableHttps) {
    // In development: src/main.ts → ../certs/
    // In production: dist/main.js → ../certs/
    const certDir = process.env.CERT_DIR || join(process.cwd(), 'certs');
    const keyPath = join(certDir, 'key.pem');
    const certPath = join(certDir, 'cert.pem');

    if (existsSync(keyPath) && existsSync(certPath)) {
      appOptions.httpsOptions = {
        key: readFileSync(keyPath),
        cert: readFileSync(certPath),
      };
      console.log('HTTPS enabled with self-signed certificate');
    } else {
      console.warn(
        'HTTPS enabled but certificates not found. Run: npm run generate-cert',
      );
      console.warn('   Falling back to HTTP...');
    }
  }

  const app = await NestFactory.create(AppModule, appOptions);

  const appConfigService = app.get(ConfigService);
  const httpPort = appConfigService.get<number>('HTTP_PORT') || 8080;
  const httpsPort = appConfigService.get<number>('HTTPS_PORT') || 8443;
  const port = enableHttps && appOptions.httpsOptions ? httpsPort : httpPort;

  // Helmet security configuration (compatible with CORS)
  app.use(
    helmet({
      crossOriginResourcePolicy: { policy: 'cross-origin' },
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          scriptSrc: ["'self'"],
          imgSrc: ["'self'", 'data:', 'https:'],
        },
      },
    }),
  );

  // Global validation pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  // Swagger configuration
  const config = new DocumentBuilder()
    .setTitle('Fitband MQTT Broker API')
    .setDescription(
      'API for managing fitband devices, telemetry ingestion, and WebSocket connections. Supports device authentication via HMAC signatures.',
    )
    .setVersion('1.0')
    .addTag('Telemetry', 'Telemetry data ingestion and retrieval')
    .addTag('Health', 'Health check endpoints')
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        description: 'Enter JWT token',
      },
      'JWT-auth',
    )
    .addApiKey(
      {
        type: 'apiKey',
        in: 'header',
        name: 'X-API-Key',
        description: 'API key for authentication',
      },
      'api-key',
    )
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api', app, document, {
    swaggerOptions: {
      persistAuthorization: true,
      tagsSorter: 'alpha',
      operationsSorter: 'alpha',
    },
  });

  await app.listen(port);

  const protocol = enableHttps && appOptions.httpsOptions ? 'https' : 'http';
  const wsProtocol = enableHttps && appOptions.httpsOptions ? 'wss' : 'ws';

  console.log('');
  console.log('Server started successfully!');
  console.log('');
  console.log(`HTTP/HTTPS API: ${protocol}://localhost:${port}`);
  console.log(`WebSocket: ${wsProtocol}://localhost:${port}/ws`);
  console.log(`Swagger docs: ${protocol}://localhost:${port}/api`);
  console.log('');

  if (enableHttps && appOptions.httpsOptions) {
    console.log('HTTPS enabled with self-signed certificate');
    console.log('Clients must accept self-signed certificates');
  } else {
    console.log('HTTP mode (unencrypted)');
    console.log('Enable HTTPS: Set ENABLE_HTTPS=true in .env');
  }
  console.log('');
}
bootstrap();
