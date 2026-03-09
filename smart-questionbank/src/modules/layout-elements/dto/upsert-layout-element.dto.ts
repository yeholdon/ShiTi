import { IsDefined } from 'class-validator';

export class UpsertLayoutElementDto {
  @IsDefined({ message: 'Missing blocks' })
  blocks!: unknown;
}
