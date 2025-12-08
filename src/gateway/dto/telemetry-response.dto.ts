import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class TelemetryResponseDto {
  @ApiProperty({
    description: 'Telemetry record ID',
    example: '1234567890',
    type: String,
  })
  id!: string;

  @ApiProperty({
    description: 'Device identifier',
    example: 'mock-001',
  })
  deviceId!: string;

  @ApiPropertyOptional({
    description: 'Session identifier if linked to an active session',
    example: '550e8400-e29b-41d4-a716-446655440000',
    nullable: true,
  })
  sessionId!: string | null;

  @ApiProperty({
    description: 'Device timestamp when telemetry was recorded',
    example: '2024-01-15T10:30:00.000Z',
  })
  tsDevice!: Date;

  @ApiProperty({
    description: 'Server timestamp when telemetry was received',
    example: '2024-01-15T10:30:00.123Z',
  })
  tsServer!: Date;

  @ApiPropertyOptional({
    description: 'Heart rate in beats per minute',
    example: 72,
    nullable: true,
  })
  heartRate!: number | null;

  @ApiPropertyOptional({
    description: 'Steps taken since last reading',
    example: 15,
    nullable: true,
  })
  stepsDelta!: number | null;

  @ApiPropertyOptional({
    description: 'Calories burned since last reading',
    example: 0.6,
    nullable: true,
    type: Number,
  })
  caloriesDelta!: number | null;

  @ApiPropertyOptional({
    description: 'Battery level (0.0 to 1.0)',
    example: 0.85,
    nullable: true,
    type: Number,
  })
  battery!: number | null;

  @ApiPropertyOptional({
    description: 'Acceleration on X-axis (g-force)',
    example: 0.123,
    nullable: true,
  })
  ax!: number | null;

  @ApiPropertyOptional({
    description: 'Acceleration on Y-axis (g-force)',
    example: -0.045,
    nullable: true,
  })
  ay!: number | null;

  @ApiPropertyOptional({
    description: 'Acceleration on Z-axis (g-force)',
    example: 0.987,
    nullable: true,
  })
  az!: number | null;

  @ApiPropertyOptional({
    description: 'Unique message identifier for idempotency',
    example: '550e8400-e29b-41d4-a716-446655440000',
    nullable: true,
  })
  messageId!: string | null;
}

