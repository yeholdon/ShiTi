import { Injectable } from '@nestjs/common';
import {
  PasswordResetDeliveryAdapter,
  PasswordResetDeliveryPayload,
  PasswordResetDeliveryResult,
} from './password-reset-delivery.types';

@Injectable()
export class PreviewPasswordResetDeliveryAdapter
  implements PasswordResetDeliveryAdapter
{
  async deliver(
    payload: PasswordResetDeliveryPayload
  ): Promise<PasswordResetDeliveryResult> {
    return {
      deliveryMode: 'preview',
      deliveryTransport: 'inline',
      deliveryTargetHint: '当前页面',
      resetTokenPreview: payload.token,
    };
  }
}
