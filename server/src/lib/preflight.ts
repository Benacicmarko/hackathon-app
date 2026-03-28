import { config } from "../config.js";

/**
 * Log clear warnings for risky or placeholder configuration.
 */
export function logConfigPreflight(): void {
  const url = config.databaseUrl;
  if (url.includes("user:password") || url.includes("postgresql://postgres:postgres@")) {
    console.warn(
      "[carpool-api] DATABASE_URL looks like a placeholder — set a real PostgreSQL URL or omit it to use the default SQLite file."
    );
  }

  if (config.authDisabled) {
    console.warn(
      "[carpool-api] Auth verification is off (DISABLE_AUTH=true, or development without Firebase). Use only for local demos."
    );
    return;
  }

  const hasJson = Boolean(config.firebaseServiceAccountJson?.trim());
  const hasAdc = Boolean(process.env.GOOGLE_APPLICATION_CREDENTIALS?.trim());

  if (!hasJson && !hasAdc) {
    console.error(
      "[carpool-api] Firebase Admin is not configured. Do one of:\n" +
        "  • Set FIREBASE_SERVICE_ACCOUNT_JSON to the full service-account JSON (one line), or\n" +
        "  • Set GOOGLE_APPLICATION_CREDENTIALS to the path of the downloaded .json file, or\n" +
        "  • Set DISABLE_AUTH=true for local testing without Firebase.\n" +
        "Get a key: Firebase Console → Project settings → Service accounts → Generate new private key.\n" +
        "Use the same Firebase project as the iOS app (see GoogleService-Info.plist PROJECT_ID)."
    );
    throw new Error("firebase_admin_not_configured");
  }
}
