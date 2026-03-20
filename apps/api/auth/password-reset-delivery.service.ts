import { Injectable } from '@nestjs/common';
import { ConsolePasswordResetDeliveryAdapter } from './console-password-reset-delivery.adapter';
import { EmailPasswordResetDeliveryAdapter } from './email-password-reset-delivery.adapter';
import { PreviewPasswordResetDeliveryAdapter } from './preview-password-reset-delivery.adapter';
import {
  PasswordResetDeliveryMode,
  PasswordResetDeliveryPayload,
  PasswordResetDeliveryResult,
} from './password-reset-delivery.types';

@Injectable()
export class PasswordResetDeliveryService {
  constructor(
    private readonly previewAdapter: PreviewPasswordResetDeliveryAdapter,
    private readonly consoleAdapter: ConsolePasswordResetDeliveryAdapter,
    private readonly emailAdapter: EmailPasswordResetDeliveryAdapter
  ) {}

  describeDelivery(
    deliveryMode: PasswordResetDeliveryMode,
    username: string
  ): Omit<PasswordResetDeliveryResult, 'resetTokenPreview'> {
    if (deliveryMode == 'console') {
      return {
        deliveryMode: 'console',
        deliveryTransport: 'console',
        deliveryTargetHint: '服务器日志',
      };
    }
    if (deliveryMode == 'email') {
      return {
        deliveryMode: 'email',
        deliveryTransport: this.emailAdapter.currentTransport(),
        deliveryTargetHint: this.emailAdapter.describeTargetHint(username),
      };
    }
    return {
      deliveryMode: 'preview',
      deliveryTransport: 'inline',
      deliveryTargetHint: '当前页面',
    };
  }

  deliverResetToken(
    payload: PasswordResetDeliveryPayload
  ): Promise<PasswordResetDeliveryResult> {
    if (payload.deliveryMode == 'console') {
      return this.consoleAdapter.deliver(payload);
    }
    if (payload.deliveryMode == 'email') {
      return this.emailAdapter.deliver(payload);
    }

    return this.previewAdapter.deliver(payload);
  }
}
