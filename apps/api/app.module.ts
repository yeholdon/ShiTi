import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PrismaModule } from '../../src/prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { TenantsModule } from './tenants/tenants.module';
import { QuestionsModule } from './questions/questions.module';
import { QuestionBanksModule } from './question-banks/question-banks.module';
import { TenantMembersModule } from './tenant-members/tenant-members.module';
import { SubjectsModule } from './subjects/subjects.module';
import { QuestionTagsModule } from './question-tags/question-tags.module';
import { DocumentsModule } from './documents/documents.module';
import { ExportJobsModule } from './export-jobs/export-jobs.module';
import { TenantResolveMiddleware } from './tenant-resolve.middleware';
import { HealthModule } from './health/health.module';
import { TextbooksModule } from './textbooks/textbooks.module';
import { ChaptersModule } from './chapters/chapters.module';
import { StagesModule } from './stages/stages.module';
import { GradesModule } from './grades/grades.module';
import { LayoutElementsModule } from './layout-elements/layout-elements.module';
import { AssetsModule } from './assets/assets.module';
import { RateLimitModule } from '../../src/common/rate-limit/rate-limit.module';
import { AuditModule } from './audit/audit.module';
import { MetricsModule } from './metrics/metrics.module';
import { AgentTeamModule } from './agent-team/agent-team.module';

@Module({
  imports: [
    PrismaModule,
    RateLimitModule,
    AuditModule,
    MetricsModule,
    AgentTeamModule,
    JwtModule.register({
      global: true,
      secret: process.env.JWT_SECRET || 'dev-secret-change-me',
      signOptions: { expiresIn: '7d' }
    }),
    AuthModule,
    TenantsModule,
    QuestionBanksModule,
    QuestionsModule,
    QuestionTagsModule,
    DocumentsModule,
    ExportJobsModule,
    TenantMembersModule,
    SubjectsModule,
    HealthModule,
    TextbooksModule,
    ChaptersModule,
    StagesModule,
    GradesModule,
    LayoutElementsModule,
    AssetsModule
  ]
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(TenantResolveMiddleware).forRoutes('*');
  }
}
