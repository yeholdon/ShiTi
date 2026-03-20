export type PasswordResetDeliveryMode = 'preview' | 'console' | 'email';

export interface PasswordResetDeliveryPayload {
  username: string;
  token: string;
  expiresAt: Date;
  deliveryMode: PasswordResetDeliveryMode;
}

export interface PasswordResetDeliveryResult {
  deliveryMode: PasswordResetDeliveryMode;
  deliveryTransport: string;
  deliveryTargetHint?: string;
  resetTokenPreview?: string;
}

export interface PasswordResetDeliveryAdapter {
  deliver(
    payload: PasswordResetDeliveryPayload
  ): Promise<PasswordResetDeliveryResult>;
}
