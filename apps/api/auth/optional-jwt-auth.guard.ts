import { ExecutionContext, Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class OptionalJwtAuthGuard extends AuthGuard('jwt') {
  handleRequest(_err: any, user: any, _info: any, ctx: ExecutionContext) {
    const req = ctx.switchToHttp().getRequest();
    if (user?.userId) {
      req.auth = { userId: user.userId };
      return user;
    }
    return null;
  }
}
