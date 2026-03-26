import { IsArray, IsBoolean, IsOptional, IsString } from "class-validator";

export class UpdateClassDto {
  @IsOptional()
  @IsString({ message: "Invalid name" })
  name?: string;

  @IsOptional()
  @IsString({ message: "Invalid stageLabel" })
  stageLabel?: string;

  @IsOptional()
  @IsString({ message: "Invalid teacherLabel" })
  teacherLabel?: string;

  @IsOptional()
  @IsString({ message: "Invalid textbookLabel" })
  textbookLabel?: string;

  @IsOptional()
  @IsString({ message: "Invalid focusLabel" })
  focusLabel?: string;

  @IsOptional()
  @IsString({ message: "Invalid focusStudentId" })
  focusStudentId?: string;

  @IsOptional()
  @IsString({ message: "Invalid focusStudentName" })
  focusStudentName?: string;

  @IsOptional()
  @IsString({ message: "Invalid lessonId" })
  lessonId?: string;

  @IsOptional()
  @IsString({ message: "Invalid lessonFocusLabel" })
  lessonFocusLabel?: string;

  @IsOptional()
  @IsString({ message: "Invalid documentId" })
  documentId?: string;

  @IsOptional()
  @IsString({ message: "Invalid latestDocLabel" })
  latestDocLabel?: string;

  @IsOptional()
  @IsArray({ message: "Invalid memberStudentIds" })
  @IsString({ each: true, message: "Invalid memberStudentIds" })
  memberStudentIds?: string[];

  @IsOptional()
  @IsBoolean({ message: "Invalid archived" })
  archived?: boolean;
}
