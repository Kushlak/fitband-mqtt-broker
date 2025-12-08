import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsUUID,
  IsNumber,
  IsDate,
  IsOptional,
  Min,
  Max,
  IsDateString,
} from 'class-validator';
import { Type } from 'class-transformer';

export class SaveTelemetryDto {
  @ApiProperty({
    description: 'Device identifier',
    example: 'mock-001',
  })
  @IsString()
  @IsUUID()
  deviceId!: string;

  @ApiProperty({
    description: 'Unique message identifier for idempotency',
    example: '550e8400-e29b-41d4-a716-446655440000',
  })
  @IsString()
  @IsUUID()
  messageId!: string;

  @ApiProperty({
    description: 'Device timestamp when telemetry was recorded (ISO 8601)',
    example: '2024-01-15T10:30:00.000Z',
  })
  @IsDateString()
  tsDevice!: string;

  @ApiProperty({
    description: 'Heart rate in beats per minute',
    example: 72,
    minimum: 40,
    maximum: 220,
  })
  @IsNumber()
  @Min(40)
  @Max(220)
  @Type(() => Number)
  heartRate!: number;

  @ApiProperty({
    description: 'Steps taken since last reading',
    example: 15,
    minimum: 0,
  })
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  stepsDelta!: number;

  @ApiProperty({
    description: 'Calories burned since last reading',
    example: 0.6,
    minimum: 0,
  })
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  caloriesDelta!: number;

  @ApiProperty({
    description: 'Battery level (0.0 to 1.0)',
    example: 0.85,
    minimum: 0,
    maximum: 1,
  })
  @IsNumber()
  @Min(0)
  @Max(1)
  @Type(() => Number)
  battery!: number;

  @ApiPropertyOptional({
    description: 'Acceleration on X-axis (g-force)',
    example: 0.123,
  })
  @IsOptional()
  @IsNumber()
  @Type(() => Number)
  ax?: number;

  @ApiPropertyOptional({
    description: 'Acceleration on Y-axis (g-force)',
    example: -0.045,
  })
  @IsOptional()
  @IsNumber()
  @Type(() => Number)
  ay?: number;

  @ApiPropertyOptional({
    description: 'Acceleration on Z-axis (g-force)',
    example: 0.987,
  })
  @IsOptional()
  @IsNumber()
  @Type(() => Number)
  az?: number;
}

