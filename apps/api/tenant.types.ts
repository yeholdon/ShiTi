export type TenantContext = {
  tenantId: string | null;
  tenantCode: string | null;
};

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      tenant?: TenantContext;
      auth?: { userId: string };
    }
  }
}
