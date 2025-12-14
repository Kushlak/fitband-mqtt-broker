import { prisma } from 'src/lib/prisma';

class PrismaService {
  constructor() {}

  async onModuleInit() {
    await prisma.$connect();
  }

  async onModuleDestroy() {
    await prisma.$disconnect();
  }
}

export { PrismaService };
