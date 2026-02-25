import { Body, Controller, Get, Headers, Post } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Controller('tenants')
export class TenantsController {
  constructor(private readonly prisma: PrismaService) {}

  @Post()
  async createTenant(@Body() body: { code: string; name: string }) {
    const existing = await this.prisma.tenant.findUnique({ where: { code: body.code } });
    if (existing) return { tenant: existing };

    const tenant = await this.prisma.tenant.create({
      data: { code: body.code, name: body.name }
    });
    return { tenant };
  }

  @Get('resolve')
  async resolve(@Headers('x-tenant-code') tenantCode: string) {
    if (!tenantCode) return { tenant: null };
    const tenant = await this.prisma.tenant.findUnique({ where: { code: tenantCode } });
    return { tenant };
  }
}
