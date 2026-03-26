import { IsOptional, IsString } from "class-validator";

export class UpdateStudentDto {
  @IsOptional()
  @IsString({ message: "Invalid name" })
  name?: string;

  @IsOptional()
  @IsString({ message: "Invalid gradeLabel" })
  gradeLabel?: string;

  @IsOptional()
  @IsString({ message: "Invalid subjectLabel" })
  subjectLabel?: string;

  @IsOptional()
  @IsString({ message: "Invalid textbookLabel" })
  textbookLabel?: string;

  @IsOptional()
  @IsString({ message: "Invalid className" })
  className?: string;

  @IsOptional()
  @IsString({ message: "Invalid classId" })
  classId?: string;

  @IsOptional()
  @IsString({ message: "Invalid lessonId" })
  lessonId?: string;

  @IsOptional()
  @IsString({ message: "Invalid documentId" })
  documentId?: string;

  @IsOptional()
  @IsString({ message: "Invalid documentName" })
  documentName?: string;
}
