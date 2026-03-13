import { ExecutionContext, Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  handleRequest(err: any, user: any, info: any, ctx: ExecutionContext) {
    const req = ctx.switchToHttp().getRequest();
    if (user?.userId) req.auth = { userId: user.userId };
    return super.handleRequest(err, user, info, ctx);
  }
}
