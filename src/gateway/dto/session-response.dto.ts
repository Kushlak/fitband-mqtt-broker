import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class SessionResponseDto {
  @ApiProperty({
    description: 'Session identifier',
    example: '550e8400-e29b-41d4-a716-446655440000',
  })
  id!: string;

  @ApiProperty({
    description: 'Device identifier',
    example: 'mock-001',
  })
  deviceId!: string;

  @ApiProperty({
    description: 'Session start timestamp',
    example: '2024-01-15T10:00:00.000Z',
  })
  startedAt!: Date;

  @ApiPropertyOptional({
    description: 'Session end timestamp (null if active)',
    example: '2024-01-15T11:00:00.000Z',
    nullable: true,
  })
  endedAt!: Date | null;

  @ApiPropertyOptional({
    description: 'Session notes',
    example: 'Morning workout session',
    nullable: true,
  })
  notes!: string | null;
}

