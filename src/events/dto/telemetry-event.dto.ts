import {
  IsNumber,
  IsUUID,
  IsDateString,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

class TelemetryPayloadDto {
  @IsNumber()
  heartRate!: number;

  @IsNumber()
  stepsDelta!: number;

  @IsNumber()
  battery!: number;

  @IsDateString()
  tsDevice!: string;
}

export class TelemetryEventDto {
  @IsUUID()
  deviceId!: string;

  @ValidateNested()
  @Type(() => TelemetryPayloadDto)
  telemetry!: TelemetryPayloadDto;
}
