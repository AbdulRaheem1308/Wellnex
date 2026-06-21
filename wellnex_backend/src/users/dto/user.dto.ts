import {
  IsString,
  IsOptional,
  IsNumber,
  IsEmail,
  Min,
  Max,
  IsArray,
  IsBoolean,
  IsNotEmpty,
  IsPhoneNumber,
} from "class-validator";
import { ApiProperty, ApiPropertyOptional } from "@nestjs/swagger";

export class CreateUserDto {
  @ApiPropertyOptional({ example: "+919876543210" })
  @IsOptional()
  @IsPhoneNumber("IN", {
    message: "Phone number must be a valid Indian mobile number (+91)",
  })
  phone?: string;

  @ApiPropertyOptional({ example: "user@example.com" })
  @IsOptional()
  @IsEmail()
  email?: string;

  @ApiPropertyOptional({ example: "John Doe" })
  @IsOptional()
  @IsString()
  name?: string;

  @ApiPropertyOptional({ example: "STEP123" })
  @IsOptional()
  @IsString()
  referredBy?: string;
}

export class UpdateUserDto {
  @ApiPropertyOptional({ example: "John Doe" })
  @IsOptional()
  @IsString()
  name?: string;

  @ApiPropertyOptional({ example: 175 })
  @IsOptional()
  @IsNumber()
  @Min(50)
  @Max(300)
  heightCm?: number;

  @ApiPropertyOptional({ example: 70 })
  @IsOptional()
  @IsNumber()
  @Min(20)
  @Max(500)
  weightKg?: number;

  @ApiPropertyOptional({ example: 30 })
  @IsOptional()
  @IsNumber()
  @Min(5)
  @Max(120)
  age?: number;

  @ApiPropertyOptional({ example: 10000 })
  @IsOptional()
  @IsNumber()
  @Min(1000)
  @Max(100000)
  dailyStepGoal?: number;

  @ApiPropertyOptional({ example: "https://example.com/avatar.png" })
  @IsOptional()
  @IsString()
  avatarUrl?: string;

  @ApiPropertyOptional({ example: "+919876543210" })
  @IsOptional()
  @IsPhoneNumber("IN", {
    message: "Phone number must be a valid Indian mobile number (+91)",
  })
  phone?: string;

  @ApiPropertyOptional({ example: "user@example.com" })
  @IsOptional()
  @IsEmail()
  email?: string;

  @ApiPropertyOptional({ example: ["walking", "running"] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  activityPreferences?: string[];

  @ApiPropertyOptional({ example: "beginner" })
  @IsOptional()
  @IsString()
  fitnessLevel?: string;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  isProfileCreated?: boolean;
}

export class ApplyReferralDto {
  @ApiProperty({ example: "STEP123", description: "Referral code to apply" })
  @IsString()
  @IsNotEmpty()
  code: string;
}

export class UpdateSettingsDto {
  @ApiPropertyOptional({ example: "dark" })
  @IsOptional()
  @IsString()
  themeMode?: string;

  @ApiPropertyOptional({ example: "en" })
  @IsOptional()
  @IsString()
  language?: string;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  pushNotifications?: boolean;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  dailyReminders?: boolean;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  soundEnabled?: boolean;

  @ApiPropertyOptional({ example: false })
  @IsOptional()
  @IsBoolean()
  dataSyncOverCellular?: boolean;

  @ApiPropertyOptional({ example: "km" })
  @IsOptional()
  @IsString()
  distanceUnit?: string;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  isPublic?: boolean;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  showOnLeaderboard?: boolean;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  showMilestones?: boolean;
}
