import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('?? Starting profile flags backfill script...');

  const accountResult = await prisma.user.updateMany({
    where: { isAccountCreated: false },
    data: { isAccountCreated: true },
  });
  console.log('? Updated ' + accountResult.count + ' users to isAccountCreated = true');

  const profileResult = await prisma.user.updateMany({
    where: {
      name: { not: null },
      heightCm: { not: null },
      weightKg: { not: null },
      age: { not: null },
      isProfileCreated: false,
    },
    data: { isProfileCreated: true },
  });
  console.log('? Updated ' + profileResult.count + ' users to isProfileCreated = true');

  console.log('?? Backfill complete!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

