-- AlterTable
ALTER TABLE "users" ADD COLUMN     "isAccountCreated" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "isProfileCreated" BOOLEAN NOT NULL DEFAULT false;

-- Data Migration: Set isProfileCreated = true for existing users who have profile details
UPDATE "users"
SET "isProfileCreated" = true
WHERE "name" IS NOT NULL
  AND "heightCm" IS NOT NULL
  AND "weightKg" IS NOT NULL
  AND "age" IS NOT NULL
  AND "fitnessLevel" IS NOT NULL
  AND cardinality("activityPreferences") > 0;
