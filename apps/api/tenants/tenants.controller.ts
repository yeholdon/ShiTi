import { Body, Controller, Get, Headers, Post } from '@nestjs/common';
import { PrismaService } from '../../../src/prisma/prisma.service';
import { CreateTenantDto } from './dto/create-tenant.dto';

@Controller('tenants')
export class TenantsController {
  constructor(private readonly prisma: PrismaService) {}

  @Post()
  async createTenant(@Body() body: CreateTenantDto) {
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
