import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
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
  listQuestionBankGrants,
  removeQuestionBankGrant,
  upsertQuestionBankGrant,
} from '../../../src/domain/questions/question-bank-access';
import { UuidIdParamDto } from '../../../src/common/dto/uuid-id-param.dto';
import { CreateQuestionBankDto } from './dto/create-question-bank.dto';
import { CreateQuestionBankGrantDto } from './dto/create-question-bank-grant.dto';
import { UpdateQuestionBankGrantDto } from './dto/update-question-bank-grant.dto';

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

  @Get(':id/grants')
  async listGrants(@Req() req: Request, @Param() params: UuidIdParamDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    const grants = await listQuestionBankGrants(
      this.prisma,
      tenantId,
      userId,
      params.id,
    );

    return {
      grants: grants.map((grant) => ({
        tenantId: grant.tenantId,
        questionBankId: grant.questionBankId,
        userId: grant.userId,
        accessLevel: grant.accessLevel,
        grantedByUserId: grant.grantedByUserId,
        grantedByUsername: grant.grantedBy.username,
        username: grant.user.username,
        createdAt: grant.createdAt,
        updatedAt: grant.updatedAt,
      })),
    };
  }

  @Post(':id/grants')
  async createGrant(
    @Req() req: Request,
    @Param() params: UuidIdParamDto,
    @Body() body: CreateQuestionBankGrantDto,
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    const grant = await upsertQuestionBankGrant(
      this.prisma,
      tenantId,
      userId,
      params.id,
      body.userId,
      body.accessLevel,
    );
    return { grant };
  }

  @Patch(':id/grants/:userId')
  async updateGrant(
    @Req() req: Request,
    @Param() params: UuidIdParamDto,
    @Param('userId', new ParseUUIDPipe({ version: '4' })) targetUserId: string,
    @Body() body: UpdateQuestionBankGrantDto,
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    const grant = await upsertQuestionBankGrant(
      this.prisma,
      tenantId,
      userId,
      params.id,
      targetUserId,
      body.accessLevel,
    );
    return { grant };
  }

  @Delete(':id/grants/:userId')
  async removeGrant(
    @Req() req: Request,
    @Param() params: UuidIdParamDto,
    @Param('userId', new ParseUUIDPipe({ version: '4' })) targetUserId: string,
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    const grant = await removeQuestionBankGrant(
      this.prisma,
      tenantId,
      userId,
      params.id,
      targetUserId,
    );
    return { grant };
  }
}
