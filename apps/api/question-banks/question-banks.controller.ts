import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { PrismaService } from '../../../src/prisma/prisma.service';
import { requireTenantId, requireUserId } from '../../../src/tenant/tenant-guards';
import {
  createCloudQuestionBank,
  ensureDefaultCloudQuestionBank,
  listAccessibleQuestionBanks,
} from '../../../src/domain/questions/question-bank-access';
import { CreateQuestionBankDto } from './dto/create-question-bank.dto';

@Controller('question-banks')
@UseGuards(JwtAuthGuard)
export class QuestionBanksController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async list(@Req() req: Request) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await ensureDefaultCloudQuestionBank(this.prisma, tenantId, userId);
    const questionBanks = await listAccessibleQuestionBanks(
      this.prisma,
      tenantId,
      userId,
    );

    return {
      questionBanks: questionBanks.map((bank) => ({
        id: bank.id,
        tenantId: bank.tenantId,
        name: bank.name,
        storageMode: bank.storageMode,
        ownerUserId: bank.ownerUserId,
        description: bank.description,
        createdAt: bank.createdAt,
        updatedAt: bank.updatedAt,
      })),
    };
  }

  @Post()
  async create(@Req() req: Request, @Body() body: CreateQuestionBankDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    if (body.storageMode === 'local') {
      throw new BadRequestException(
        'Local question banks are desktop-local only and are not created through cloud API',
      );
    }

    const questionBank = await createCloudQuestionBank(this.prisma, tenantId, userId, {
      name: body.name,
      description: body.description,
    });

    return { questionBank };
  }
}
