import { createHash } from "node:crypto";
import * as admin from "firebase-admin";
import { config } from "../config.js";

function decodedIdTokenForDevToken(token: string): admin.auth.DecodedIdToken {
  const t = token.trim();
  if (!t || t === "dummy") {
    return {
      uid: "dev_anonymous",
      email: "anonymous@dev.local",
      name: "Dev anonymous",
    } as unknown as admin.auth.DecodedIdToken;
  }
  const h = createHash("sha256").update(t).digest("hex").slice(0, 32);
  return {
    uid: `dev_${h}`,
    email: `${h.slice(0, 10)}@dev.local`,
    name: `Dev ${h.slice(0, 6)}`,
  } as unknown as admin.auth.DecodedIdToken;
}

let initialized = false;

export function initFirebaseAdmin(): void {
  if (initialized) return;
  if (config.authDisabled) {
    initialized = true;
    return;
  }
  if (admin.apps.length > 0) {
    initialized = true;
    return;
  }
  if (config.firebaseServiceAccountJson?.trim()) {
    let cred: admin.ServiceAccount;
    try {
      cred = JSON.parse(config.firebaseServiceAccountJson) as admin.ServiceAccount;
    } catch {
      throw new Error(
        "FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON. Paste the full service account key as one line."
      );
    }
    admin.initializeApp({ credential: admin.credential.cert(cred) });
  } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS?.trim()) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  } else {
    throw new Error(
      "Firebase Admin: set FIREBASE_SERVICE_ACCOUNT_JSON or GOOGLE_APPLICATION_CREDENTIALS (or DISABLE_AUTH=true)."
    );
  }
  initialized = true;
}

export async function verifyIdToken(token: string): Promise<admin.auth.DecodedIdToken> {
  initFirebaseAdmin();
  if (config.authDisabled) {
    return decodedIdTokenForDevToken(token);
  }
  return admin.auth().verifyIdToken(token);
}
