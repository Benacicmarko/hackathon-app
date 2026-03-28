# Carpool API (Fastify + Prisma)

Implements [docs/carpool-city-02-technical.md](../docs/carpool-city-02-technical.md) §12 REST surface. **Backend only** — no need to run the iOS app to develop this service.

## Run locally (nothing else required)

From `server/`:

```bash
npm install
npm run setup    # creates prisma/dev.db and applies migrations
npm run dev
```

- **Default database:** SQLite at `prisma/dev.db` (no PostgreSQL or Docker).
- **Default auth:** If Firebase credentials are not set, ID tokens are not verified in development (same effect as `DISABLE_AUTH=true`). Set `DISABLE_AUTH=false` and configure Firebase to test real tokens.
- **Default maps:** If `GOOGLE_MAPS_API_KEY` is empty, geocoding and routes use deterministic mocks so routing and stops still work.

Health: `GET http://localhost:3000/health`. API: `http://localhost:3000/v1`.

## Optional: PostgreSQL

Copy `.env.example` to `.env` and set `DATABASE_URL` to a PostgreSQL URL. The Prisma schema targets SQLite by default; for PostgreSQL you would change `provider` in `prisma/schema.prisma` and add a matching migration (or use `db push` for experiments). The repo also includes `docker compose` for a local Postgres matching the old sample URL.

## Google Cloud APIs required

The backend calls exactly **two** Google APIs (both with the same `GOOGLE_MAPS_API_KEY`):

| API | What it does in this app |
|-----|--------------------------|
| **Geocoding API** | Converts address strings → lat/lng (used in match ranking and route building). |
| **Routes API** (`computeRoutes`) | Computes the driving route with ordered waypoints; returns per-leg durations and optional polyline. |

Enable both in [Google Cloud Console](https://console.cloud.google.com/) on the same project/key. No other Google APIs (Directions, Distance Matrix, Places, Maps SDK) are called from the server.

## Production-style setup

1. **PostgreSQL** — Railway, Neon, RDS, or `docker compose up -d` in `server/`.
2. **Firebase Admin** — Firebase Console → Project settings → Service accounts → Generate new private key. Set `FIREBASE_SERVICE_ACCOUNT_JSON` (single line) or `GOOGLE_APPLICATION_CREDENTIALS`.
3. **Google Maps** — Enable **Geocoding API** and **Routes API** on the same key; set `GOOGLE_MAPS_API_KEY`.

## Scripts

| Script | Purpose |
|--------|---------|
| `npm run dev` | Hot reload with `tsx watch` |
| `npm run setup` | `prisma migrate deploy` (creates/updates local DB) |
| `npm run dev:ready` | `setup` then `dev` |
| `npm run build` | `tsc` → `dist/` |
| `npm start` | Run compiled JS |
| `npm run db:migrate` | Same as `setup` |
| `npm run db:studio` | Prisma Studio |

Required headers and bodies match the technical spec §10–§12 (`clientTimeZone`, ISO `departureDate`, etc.).
