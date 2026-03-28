import type { FastifyReply, FastifyRequest } from "fastify";
import { verifyIdToken } from "../lib/firebaseAdmin.js";
import { prisma } from "../lib/prisma.js";
import { config } from "../config.js";

declare module "fastify" {
  interface FastifyRequest {
    user?: {
      id: string;
      firebaseUid: string;
      email: string | null;
      displayName: string | null;
    };
  }
}

async function authenticate(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  const auth = request.headers.authorization;
  const token =
    auth?.startsWith("Bearer ") ? auth.slice("Bearer ".length).trim() : "";

  if (!token && !config.authDisabled) {
    return reply.code(401).send({ error: "missing_bearer_token" });
  }

  try {
    const decoded = await verifyIdToken(token || "dummy");
    const firebaseUid = decoded.uid;
    const email = decoded.email ?? null;
    const displayName =
      (decoded.name as string | undefined) ??
      (email ? email.split("@")[0] : null) ??
      "User";

    const user = await prisma.user.upsert({
      where: { firebaseUid },
      create: {
        firebaseUid,
        email,
        displayName,
      },
      update: {
        email: email ?? undefined,
        displayName: displayName ?? undefined,
      },
    });

    request.user = {
      id: user.id,
      firebaseUid: user.firebaseUid,
      email: user.email,
      displayName: user.displayName,
    };
  } catch {
    return reply.code(401).send({ error: "invalid_token" });
  }
}

export { authenticate };
