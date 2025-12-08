import { ApiProperty } from '@nestjs/swagger';

export class DeviceResponseDto {
  @ApiProperty({
    description: 'Device identifier',
    example: 'mock-001',
  })
  id!: string;

  @ApiProperty({
    description: 'Device name',
    example: 'Fitband Device 001',
  })
  name!: string;

  @ApiProperty({
    description: 'Device secret for HMAC verification',
    example: 'secret-key-here',
  })
  secret!: string;

  @ApiProperty({
    description: 'Device creation timestamp',
    example: '2024-01-15T10:00:00.000Z',
  })
  createdAt!: Date;

  @ApiProperty({
    description: 'User identifier',
    example: '550e8400-e29b-41d4-a716-446655440000',
  })
  userId!: string;
}

