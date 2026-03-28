# Demo runbook — carpool MVP

## Prerequisites (minimal)

1. **Backend:** from [server/README.md](../server/README.md) — `npm install`, `npm run setup`, `npm run dev` on port 3000. Uses **SQLite** (`prisma/dev.db`) and mock Maps when no API key; **Firebase is optional** in development (auth auto-disabled without credentials).
2. **Full demo (real geocoding / production):** optional `GOOGLE_MAPS_API_KEY` (Geocoding + Routes API) and Firebase Admin JSON for real ID tokens.
3. **iOS:** `API_BASE_URL` set to that URL; user signed in with Firebase Auth when auth is enabled.

## Quick API check

```bash
cd server && npm run setup && npm run dev
curl -s http://localhost:3000/health
curl -s http://localhost:3000/v1/me
```

## Happy path (two devices / two users)

1. **Driver** (user A): `POST /v1/driver-intents` with `departureDate`, addresses, `passengerSeats: 2`, `clientTimeZone`.
2. **Rider** (user B): `POST /v1/driver-intents/matches` with same `departureDate`, rider addresses, `wantedArrivalAt`, `clientTimeZone` — pick an `intentId`.
3. **Rider B** and **Rider C** (or second session): `POST /v1/driver-intents/:intentId/applications` until `seatsFilled == seatsTotal`.
4. Expect `status` → `confirmed` and `GET /v1/driver-intents/:id/detail` returns `stops[]` (mock route legs work without a Maps key; use a real key for accurate geometry).

## Docs

- Product: [carpool-city-01-product.md](./carpool-city-01-product.md)
- Technical: [carpool-city-02-technical.md](./carpool-city-02-technical.md)
- Checklist: [carpool-city-03-checklist.md](./carpool-city-03-checklist.md)
