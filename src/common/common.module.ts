import { Module } from '@nestjs/common';
import { PrismaService } from './Prisma.Service';

@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class CommonModule {}