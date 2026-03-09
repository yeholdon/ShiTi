import { IsArray, IsDefined, IsString } from 'class-validator';

export class SetQuestionTagsDto {
  @IsDefined({ message: 'Missing tagIds' })
  @IsArray({ message: 'Missing tagIds' })
  @IsString({ each: true, message: 'Invalid tagIds' })
  tagIds!: string[];
}
