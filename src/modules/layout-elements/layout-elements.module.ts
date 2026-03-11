import { Module } from '@nestjs/common';
import { LayoutElementsController } from './layout-elements.controller';

@Module({
  controllers: [LayoutElementsController]
})
export class LayoutElementsModule {}
