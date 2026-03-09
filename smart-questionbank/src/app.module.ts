import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './modules/auth/auth.module';
import { TenantsModule } from './modules/tenants/tenants.module';
import { QuestionsModule } from './modules/questions/questions.module';
import { TenantMembersModule } from './modules/tenant-members/tenant-members.module';
import { SubjectsModule } from './modules/subjects/subjects.module';
import { QuestionTagsModule } from './modules/question-tags/question-tags.module';
import { DocumentsModule } from './modules/documents/documents.module';
import { ExportJobsModule } from './modules/export-jobs/export-jobs.module';
import { TenantResolveMiddleware } from './tenant/tenant-resolve.middleware';
import { HealthModule } from './modules/health/health.module';
import { TextbooksModule } from './modules/textbooks/textbooks.module';
import { ChaptersModule } from './modules/chapters/chapters.module';
import { StagesModule } from './modules/stages/stages.module';
import { GradesModule } from './modules/grades/grades.module';
import { LayoutElementsModule } from './modules/layout-elements/layout-elements.module';
import { AssetsModule } from './modules/assets/assets.module';
import { RateLimitModule } from './common/rate-limit/rate-limit.module';
import { AuditModule } from './common/audit/audit.module';
import { MetricsModule } from './common/metrics/metrics.module';

@Module({
  imports: [
    PrismaModule,
    RateLimitModule,
    AuditModule,
    MetricsModule,
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
