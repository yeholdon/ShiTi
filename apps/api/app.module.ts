import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PrismaModule } from '../../src/prisma/prisma.module';
import { AuthModule } from '../../src/modules/auth/auth.module';
import { TenantsModule } from '../../src/modules/tenants/tenants.module';
import { QuestionsModule } from '../../src/modules/questions/questions.module';
import { TenantMembersModule } from '../../src/modules/tenant-members/tenant-members.module';
import { SubjectsModule } from '../../src/modules/subjects/subjects.module';
import { QuestionTagsModule } from '../../src/modules/question-tags/question-tags.module';
import { DocumentsModule } from '../../src/modules/documents/documents.module';
import { ExportJobsModule } from '../../src/modules/export-jobs/export-jobs.module';
import { TenantResolveMiddleware } from './tenant-resolve.middleware';
import { HealthModule } from '../../src/modules/health/health.module';
import { TextbooksModule } from '../../src/modules/textbooks/textbooks.module';
import { ChaptersModule } from '../../src/modules/chapters/chapters.module';
import { StagesModule } from '../../src/modules/stages/stages.module';
import { GradesModule } from '../../src/modules/grades/grades.module';
import { LayoutElementsModule } from '../../src/modules/layout-elements/layout-elements.module';
import { AssetsModule } from '../../src/modules/assets/assets.module';
import { RateLimitModule } from '../../src/common/rate-limit/rate-limit.module';
import { AuditModule } from '../../src/common/audit/audit.module';
import { MetricsModule } from '../../src/common/metrics/metrics.module';
import { AgentTeamModule } from '../../src/modules/agent-team/agent-team.module';

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
