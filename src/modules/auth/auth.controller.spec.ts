import { AuthController } from './auth.controller';

describe('AuthController', () => {
  it('register creates user and issues token', async () => {
    const prisma = { user: { create: jest.fn().mockResolvedValue({ id: 'u1' }) } } as any;
    const auth = { issueToken: jest.fn().mockResolvedValue({ accessToken: 't' }) } as any;
    const ctrl = new AuthController(prisma, auth);

    const res = await ctrl.register({ username: 'alice' });

    expect(prisma.user.create).toHaveBeenCalledWith({ data: { username: 'alice', passwordHash: 'dev' } });
    expect(auth.issueToken).toHaveBeenCalledWith('u1');
    expect(res).toEqual({ accessToken: 't' });
  });

  it('login finds user and issues token', async () => {
    const prisma = { user: { findUnique: jest.fn().mockResolvedValue({ id: 'u2' }) } } as any;
    const auth = { issueToken: jest.fn().mockResolvedValue({ accessToken: 't2' }) } as any;
    const ctrl = new AuthController(prisma, auth);

    const res = await ctrl.login({ username: 'bob' });

    expect(prisma.user.findUnique).toHaveBeenCalledWith({ where: { username: 'bob' } });
    expect(auth.issueToken).toHaveBeenCalledWith('u2');
    expect(res).toEqual({ accessToken: 't2' });
  });
});
