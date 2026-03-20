import { Injectable } from '@nestjs/common';
import {
  PasswordResetDeliveryAdapter,
  PasswordResetDeliveryPayload,
  PasswordResetDeliveryResult,
} from './password-reset-delivery.types';

@Injectable()
export class ConsolePasswordResetDeliveryAdapter
  implements PasswordResetDeliveryAdapter
{
  async deliver(
    payload: PasswordResetDeliveryPayload
  ): Promise<PasswordResetDeliveryResult> {
    console.info(
      `[auth.reset-password] username=${payload.username} token=${payload.token} expiresAt=${payload.expiresAt.toISOString()}`
    );
    return {
      deliveryMode: 'console',
      deliveryTransport: 'console',
      deliveryTargetHint: '服务器日志',
    };
  }
}
