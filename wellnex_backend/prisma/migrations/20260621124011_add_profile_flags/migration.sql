-- AlterTable
ALTER TABLE "users" ADD COLUMN     "isAccountCreated" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "isProfileCreated" BOOLEAN NOT NULL DEFAULT false;
