import { config } from "./config.js";
import Fastify from "fastify";
import cors from "@fastify/cors";
import { initFirebaseAdmin } from "./lib/firebaseAdmin.js";
import { logConfigPreflight } from "./lib/preflight.js";
import { registerV1Routes } from "./routes/v1.js";

async function main(): Promise<void> {
  logConfigPreflight();
  initFirebaseAdmin();

  const app = Fastify({
    logger: true,
  });

  await app.register(cors, {
    origin: true,
  });

  app.get("/health", async () => ({ ok: true, service: "carpool-api" }));

  await app.register(
    async (v1) => {
      await registerV1Routes(v1);
    },
    { prefix: "/v1" }
  );

  await app.listen({ port: config.port, host: config.host });
  app.log.info(`Listening on http://${config.host}:${config.port}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
