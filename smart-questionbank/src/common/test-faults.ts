import type { Request } from 'express';

export function hasTestFault(req: Request, fault: string) {
  if (process.env.NODE_ENV !== 'test') return false;

  const raw = req.header('X-Test-Fault');
  if (!raw) return false;

  return raw
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
    .includes(fault);
}
