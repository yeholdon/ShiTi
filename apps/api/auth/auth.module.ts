import { Module } from '@nestjs/common';
import { PassportModule } from '@nestjs/passport';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { ConsolePasswordResetDeliveryAdapter } from './console-password-reset-delivery.adapter';
import { EmailPasswordResetDeliveryAdapter } from './email-password-reset-delivery.adapter';
import { JwtStrategy } from './jwt.strategy';
import { PasswordResetEmailGateway } from './password-reset-email.gateway';
import { PasswordResetDeliveryService } from './password-reset-delivery.service';
import { PreviewPasswordResetDeliveryAdapter } from './preview-password-reset-delivery.adapter';

@Module({
  imports: [PassportModule],
  controllers: [AuthController],
  providers: [
    AuthService,
    JwtStrategy,
    PasswordResetEmailGateway,
    PreviewPasswordResetDeliveryAdapter,
    ConsolePasswordResetDeliveryAdapter,
    EmailPasswordResetDeliveryAdapter,
    PasswordResetDeliveryService,
  ],
  exports: [AuthService]
})
export class AuthModule {}
