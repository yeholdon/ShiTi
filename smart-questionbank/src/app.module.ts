import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './modules/auth/auth.module';
import { TenantsModule } from './modules/tenants/tenants.module';
import { QuestionsModule } from './modules/questions/questions.module';
import { TenantMembersModule } from './modules/tenant-members/tenant-members.module';
import { SubjectsModule } from './modules/subjects/subjects.module';
import { QuestionTagsModule } from './modules/question-tags/question-tags.module';
import { TenantResolveMiddleware } from './tenant/tenant-resolve.middleware';

@Module({
  imports: [
    PrismaModule,
    JwtModule.register({
      global: true,
      secret: process.env.JWT_SECRET || 'dev-secret-change-me',
      signOptions: { expiresIn: '7d' }
    }),
    AuthModule,
    TenantsModule,
    QuestionsModule,
    QuestionTagsModule,
    TenantMembersModule,
    SubjectsModule
  ]
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(TenantResolveMiddleware).forRoutes('*');
  }
}
