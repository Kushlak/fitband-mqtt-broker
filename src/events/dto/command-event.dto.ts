import { IsString, IsUUID, IsOptional } from 'class-validator';

export class CommandEventDto {
  @IsUUID()
  deviceId!: string;

  @IsString()
  command!: string;

  @IsOptional()
  payload?: any;
}
