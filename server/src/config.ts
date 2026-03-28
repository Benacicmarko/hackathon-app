import "dotenv/config";

const defaultSqliteUrl = "file:./prisma/dev.db";

{
  const raw = process.env.DATABASE_URL?.trim() || "";
  if (!raw) {
    process.env.DATABASE_URL = defaultSqliteUrl;
  } else if (raw.startsWith("postgresql:") || raw.startsWith("postgres:")) {
    console.warn(
      "[carpool-api] DATABASE_URL points at PostgreSQL but this package uses SQLite. Using file:./prisma/dev.db. Remove or change DATABASE_URL in .env if you switched Prisma to PostgreSQL."
    );
    process.env.DATABASE_URL = defaultSqliteUrl;
  } else if (!raw.startsWith("file:")) {
    console.warn("[carpool-api] DATABASE_URL must be a file: URL for SQLite; using default file:./prisma/dev.db.");
    process.env.DATABASE_URL = defaultSqliteUrl;
  }
}

const nodeEnv = process.env.NODE_ENV || "development";
const hasFirebase =
  Boolean(process.env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim()) ||
  Boolean(process.env.GOOGLE_APPLICATION_CREDENTIALS?.trim());

/** Explicit false keeps Firebase required in development (for testing token verification). */
let authDisabled = process.env.DISABLE_AUTH === "true";
if (!authDisabled && process.env.DISABLE_AUTH !== "false") {
  if (nodeEnv === "development" && !hasFirebase) {
    authDisabled = true;
  }
}

export const config = {
  port: Number(process.env.PORT) || 3000,
  host: process.env.HOST || "0.0.0.0",
  nodeEnv,
  databaseUrl: process.env.DATABASE_URL!,
  googleMapsApiKey: process.env.GOOGLE_MAPS_API_KEY || "",
  /** JSON string of Firebase service account (for Railway) or use GOOGLE_APPLICATION_CREDENTIALS */
  firebaseServiceAccountJson: process.env.FIREBASE_SERVICE_ACCOUNT_JSON || "",
  /** Skip Firebase verification — true if DISABLE_AUTH=true, or dev default when Firebase is not configured */
  authDisabled,
};
