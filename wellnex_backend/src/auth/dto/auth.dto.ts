import {
  IsString,
  IsOptional,
  IsPhoneNumber,
  IsEmail,
  Length,
} from "class-validator";

export class SendOtpDto {
  @IsOptional()
  @IsPhoneNumber("IN", {
    message: "Phone number must be a valid Indian mobile number (+91)",
  })
  phone?: string;

  @IsOptional()
  @IsEmail()
  email?: string;
}

export class VerifyOtpDto {
  @IsOptional()
  @IsPhoneNumber("IN", {
    message: "Phone number must be a valid Indian mobile number (+91)",
  })
  phone?: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsString()
  @Length(4, 8)
  otp: string;

  @IsOptional()
  @IsString()
  referralCode?: string;
}

export class RefreshTokenDto {
  @IsString()
  refreshToken: string;
}

export class SocialLoginDto {
  @IsString()
  idToken: string;

  @IsOptional()
  @IsString()
  referralCode?: string;
}
