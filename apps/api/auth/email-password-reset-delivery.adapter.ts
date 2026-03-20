import { Injectable } from '@nestjs/common';
import { PasswordResetEmailGateway } from './password-reset-email.gateway';
import {
  PasswordResetDeliveryAdapter,
  PasswordResetDeliveryPayload,
  PasswordResetDeliveryResult,
} from './password-reset-delivery.types';

@Injectable()
export class EmailPasswordResetDeliveryAdapter
  implements PasswordResetDeliveryAdapter
{
  constructor(private readonly emailGateway: PasswordResetEmailGateway) {}

  currentTransport(): string {
    return this.emailGateway.currentTransport();
  }

  describeTargetHint(value: string): string {
    const parts = value.split('@');
    if (parts.length != 2) {
      return value;
    }
    const local = parts[0];
    const domain = parts[1];
    if (local.length <= 2) {
      return `${local[0] ?? '*'}*@${domain}`;
    }
    return `${local[0]}***${local[local.length - 1]}@${domain}`;
  }

  async deliver(
    payload: PasswordResetDeliveryPayload
  ): Promise<PasswordResetDeliveryResult> {
    const sent = await this.emailGateway.send(
      this.emailGateway.buildMessage({
        to: payload.username,
        token: payload.token,
        expiresAt: payload.expiresAt,
      })
    );
    return {
      deliveryMode: 'email',
      deliveryTransport: sent.transport,
      deliveryTargetHint: this.describeTargetHint(payload.username),
    };
  }
}
