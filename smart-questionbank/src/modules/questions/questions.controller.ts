import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  Put,
  Req,
  UseGuards
} from '@nestjs/common';
import type { Request } from 'express';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { requireActiveTenantMember, requireTenantId, requireUserId } from '../../tenant/tenant-guards';

@Controller('questions')
@UseGuards(JwtAuthGuard)
export class QuestionsController {
  constructor(private readonly prisma: PrismaService) {}

  @Post()
  async create(@Req() req: Request, @Body() body: { subjectId?: string }) {
    const tenantId = requireTenantId(req);
    const ownerUserId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, ownerUserId);

    const subjectId =
      body.subjectId ||
      (await this.prisma.subject
        .findFirst({ where: { tenantId: null, isSystem: true }, orderBy: { createdAt: 'asc' } })
        .then((s) => s?.id));

    if (!subjectId) throw new Error('No system subject found; run prisma seed');

    const question = await this.prisma.withTenant(tenantId, (tx) =>
      tx.question.create({
        data: {
          tenantId,
          type: 'single_choice',
          difficulty: 3,
          defaultScore: '5.00',
          subjectId,
          ownerUserId,
          visibility: 'private'
        }
      })
    );

    return { question };
  }

  @Get()
  async list(@Req() req: Request) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const result = await this.prisma.withTenant(tenantId, async (tx) => {
      const questions = await tx.question.findMany({ take: 50, orderBy: { createdAt: 'desc' } });
      return { questions };
    });

    return result;
  }

  @Get(':id')
  async getOne(@Req() req: Request, @Param('id') id: string) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');

    const question = await this.prisma.withTenant(tenantId, (tx) => tx.question.findUnique({ where: { tenantId_id: { tenantId, id } } }));
    if (!question) throw new NotFoundException('Question not found');

    const [content, explanation, source, choiceAnswer, blankAnswer, solutionAnswer] = await this.prisma.withTenant(
      tenantId,
      async (tx) => {
        const result = await Promise.all([
          tx.questionContent.findUnique({ where: { tenantId_questionId: { tenantId, questionId: id } } }),
          tx.questionExplanation.findUnique({ where: { tenantId_questionId: { tenantId, questionId: id } } }),
          tx.questionSource.findUnique({ where: { tenantId_questionId: { tenantId, questionId: id } } }),
          tx.questionAnswerChoice.findUnique({ where: { tenantId_questionId: { tenantId, questionId: id } } }),
          tx.questionAnswerBlank.findUnique({ where: { tenantId_questionId: { tenantId, questionId: id } } }),
          tx.questionAnswerSolution.findUnique({ where: { tenantId_questionId: { tenantId, questionId: id } } })
        ]);
        return result;
      }
    );

    return { question, content, explanation, source, choiceAnswer, blankAnswer, solutionAnswer };
  }

  @Patch(':id')
  async update(@Req() req: Request, @Param('id') id: string, @Body() body: any) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');

    const data: any = {};
    if (body.type) data.type = body.type;
    if (typeof body.difficulty === 'number') data.difficulty = body.difficulty;
    if (body.defaultScore != null) data.defaultScore = body.defaultScore;
    if (body.subjectId) data.subjectId = body.subjectId;
    if (body.visibility) data.visibility = body.visibility;

    const question = await this.prisma.withTenant(tenantId, (tx) =>
      tx.question.update({
        where: { tenantId_id: { tenantId, id } },
        data
      })
    );

    return { question };
  }

  @Delete(':id')
  async remove(@Req() req: Request, @Param('id') id: string) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');

    await this.prisma.withTenant(tenantId, (tx) => tx.question.delete({ where: { tenantId_id: { tenantId, id } } }));

    return { ok: true };
  }

  @Put(':id/content')
  async upsertContent(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() body: { stemBlocks: Prisma.InputJsonValue }
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');
    if (body?.stemBlocks == null) throw new BadRequestException('Missing stemBlocks');

    const content = await this.prisma.withTenant(tenantId, async (tx) => {
      const question = await tx.question.findUnique({ where: { tenantId_id: { tenantId, id } } });
      if (!question) throw new NotFoundException('Question not found');

      return tx.questionContent.upsert({
        where: { tenantId_questionId: { tenantId, questionId: id } },
        create: { tenantId, questionId: id, stemBlocks: body.stemBlocks },
        update: { stemBlocks: body.stemBlocks }
      });
    });

    return { content };
  }

  @Put(':id/explanation')
  async upsertExplanation(
    @Req() req: Request,
    @Param('id') id: string,
    @Body()
    body: {
      overviewLatex?: string | null;
      stepsBlocks: Prisma.InputJsonValue;
      commentaryLatex?: string | null;
    }
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');
    if (body?.stepsBlocks == null) throw new BadRequestException('Missing stepsBlocks');

    const explanation = await this.prisma.withTenant(tenantId, async (tx) => {
      const question = await tx.question.findUnique({ where: { tenantId_id: { tenantId, id } } });
      if (!question) throw new NotFoundException('Question not found');

      return tx.questionExplanation.upsert({
        where: { tenantId_questionId: { tenantId, questionId: id } },
        create: {
          tenantId,
          questionId: id,
          overviewLatex: body.overviewLatex ?? null,
          stepsBlocks: body.stepsBlocks,
          commentaryLatex: body.commentaryLatex ?? null
        },
        update: {
          overviewLatex: body.overviewLatex ?? null,
          stepsBlocks: body.stepsBlocks,
          commentaryLatex: body.commentaryLatex ?? null
        }
      });
    });

    return { explanation };
  }

  @Put(':id/source')
  async upsertSource(
    @Req() req: Request,
    @Param('id') id: string,
    @Body()
    body: {
      year?: number | null;
      month?: number | null;
      sourceText?: string | null;
    }
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');

    const source = await this.prisma.withTenant(tenantId, async (tx) => {
      const question = await tx.question.findUnique({ where: { tenantId_id: { tenantId, id } } });
      if (!question) throw new NotFoundException('Question not found');

      return tx.questionSource.upsert({
        where: { tenantId_questionId: { tenantId, questionId: id } },
        create: {
          tenantId,
          questionId: id,
          year: body.year ?? null,
          month: body.month ?? null,
          sourceText: body.sourceText ?? null
        },
        update: {
          year: body.year ?? null,
          month: body.month ?? null,
          sourceText: body.sourceText ?? null
        }
      });
    });

    return { source };
  }
}
