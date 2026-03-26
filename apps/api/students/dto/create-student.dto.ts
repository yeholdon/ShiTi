import { IsNotEmpty, IsOptional, IsString } from "class-validator";

export class CreateStudentDto {
  @IsString({ message: "Missing name" })
  @IsNotEmpty({ message: "Missing name" })
  name!: string;

  @IsString({ message: "Missing gradeLabel" })
  @IsNotEmpty({ message: "Missing gradeLabel" })
  gradeLabel!: string;

  @IsString({ message: "Missing subjectLabel" })
  @IsNotEmpty({ message: "Missing subjectLabel" })
  subjectLabel!: string;

  @IsString({ message: "Missing textbookLabel" })
  @IsNotEmpty({ message: "Missing textbookLabel" })
  textbookLabel!: string;

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
