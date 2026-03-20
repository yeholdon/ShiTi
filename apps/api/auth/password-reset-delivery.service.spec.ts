import { EmailPasswordResetDeliveryAdapter } from './email-password-reset-delivery.adapter';
import { ConsolePasswordResetDeliveryAdapter } from './console-password-reset-delivery.adapter';
import { PasswordResetDeliveryService } from './password-reset-delivery.service';
import { PreviewPasswordResetDeliveryAdapter } from './preview-password-reset-delivery.adapter';

describe('PasswordResetDeliveryService', () => {
  it('routes preview mode through the preview adapter', async () => {
    const previewAdapter = {
      deliver: jest.fn().mockResolvedValue({
        deliveryMode: 'preview',
        deliveryTransport: 'inline',
        deliveryTargetHint: '当前页面',
        resetTokenPreview: 'preview-token',
      }),
    } as any as PreviewPasswordResetDeliveryAdapter;
    const consoleAdapter = {
      deliver: jest.fn(),
    } as any as ConsolePasswordResetDeliveryAdapter;
    const emailAdapter = {
      deliver: jest.fn(),
    } as any as EmailPasswordResetDeliveryAdapter;
    const service = new PasswordResetDeliveryService(
      previewAdapter,
      consoleAdapter,
      emailAdapter
    );

    const result = await service.deliverResetToken({
      username: 'alice',
      token: 'preview-token',
      expiresAt: new Date('2026-03-16T05:00:00.000Z'),
      deliveryMode: 'preview',
    });

    expect(previewAdapter.deliver).toHaveBeenCalled();
    expect(consoleAdapter.deliver).not.toHaveBeenCalled();
    expect(emailAdapter.deliver).not.toHaveBeenCalled();
    expect(result).toEqual({
      deliveryMode: 'preview',
      deliveryTransport: 'inline',
      deliveryTargetHint: '当前页面',
      resetTokenPreview: 'preview-token',
    });
  });

  it('routes console mode through the console adapter', async () => {
    const previewAdapter = {
      deliver: jest.fn(),
    } as any as PreviewPasswordResetDeliveryAdapter;
    const consoleAdapter = {
      deliver: jest.fn().mockResolvedValue({
        deliveryMode: 'console',
        deliveryTransport: 'console',
        deliveryTargetHint: '服务器日志',
      }),
    } as any as ConsolePasswordResetDeliveryAdapter;
    const emailAdapter = {
      deliver: jest.fn(),
    } as any as EmailPasswordResetDeliveryAdapter;
    const service = new PasswordResetDeliveryService(
      previewAdapter,
      consoleAdapter,
      emailAdapter
    );

    const result = await service.deliverResetToken({
      username: 'alice',
      token: 'console-token',
      expiresAt: new Date('2026-03-16T05:00:00.000Z'),
      deliveryMode: 'console',
    });

    expect(consoleAdapter.deliver).toHaveBeenCalled();
    expect(previewAdapter.deliver).not.toHaveBeenCalled();
    expect(emailAdapter.deliver).not.toHaveBeenCalled();
    expect(result).toEqual({
      deliveryMode: 'console',
      deliveryTransport: 'console',
      deliveryTargetHint: '服务器日志',
    });
  });

  it('routes email mode through the email adapter', async () => {
    const previewAdapter = {
      deliver: jest.fn(),
    } as any as PreviewPasswordResetDeliveryAdapter;
    const consoleAdapter = {
      deliver: jest.fn(),
    } as any as ConsolePasswordResetDeliveryAdapter;
    const emailAdapter = {
      deliver: jest.fn().mockResolvedValue({
        deliveryMode: 'email',
        deliveryTransport: 'console',
        deliveryTargetHint: 't***r@example.com',
      }),
    } as any as EmailPasswordResetDeliveryAdapter;
    const service = new PasswordResetDeliveryService(
      previewAdapter,
      consoleAdapter,
      emailAdapter
    );

    const result = await service.deliverResetToken({
      username: 'teacher@example.com',
      token: 'email-token',
      expiresAt: new Date('2026-03-16T05:00:00.000Z'),
      deliveryMode: 'email',
    });

    expect(emailAdapter.deliver).toHaveBeenCalled();
    expect(previewAdapter.deliver).not.toHaveBeenCalled();
    expect(consoleAdapter.deliver).not.toHaveBeenCalled();
    expect(result).toEqual({
      deliveryMode: 'email',
      deliveryTransport: 'console',
      deliveryTargetHint: 't***r@example.com',
    });
  });
});
