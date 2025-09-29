import { PrismaClient } from "@prisma/client";

declare global {
  var prisma: PrismaClient | undefined;
}

function resolveDatabaseUrl(): string | undefined {
  // Prefer explicit Postgres vars
  if (process.env.POSTGRES_PRISMA_URL) return process.env.POSTGRES_PRISMA_URL;
  if (process.env.DATABASE_URL) return process.env.DATABASE_URL;
  // Fallback to local SQLite dev DB
  return "file:./dev.db";
}

const datasourceUrl = resolveDatabaseUrl();

const prisma =
  global.prisma ||
  new PrismaClient({
    datasources: {
      db: { url: datasourceUrl },
    },
  });

if (process.env.NODE_ENV === "development") global.prisma = prisma;

export default prisma;
