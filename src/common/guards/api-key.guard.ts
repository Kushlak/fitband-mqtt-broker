import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class ApiKeyGuard implements CanActivate {
  constructor(private readonly configService: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const apiKey = this.configService.get<string>('API_KEY');
    if (!apiKey) return true; // dev mode: no key set → allow all

    const request = context.switchToHttp().getRequest();
    const header = request.headers['x-api-key'] || request.headers['X-API-KEY'];

    if (!header || header !== apiKey) {
      throw new UnauthorizedException('Invalid API key');
    }
    return true;
  }
}
