# iOS app ↔ Backend API — integration guide

**Audience:** Frontend (iOS) agent — SwiftUI, `URLSession` (or Alamofire), Firebase Auth.  
**Backend:** Fastify service in [`server/`](../server/); contract matches [carpool-city-02-technical.md §12](./carpool-city-02-technical.md) and the live routes in `server/src/routes/v1.ts`.

**Related:** [AGENT_INSTRUCTIONS.md](./AGENT_INSTRUCTIONS.md) (two-agent split), [carpool-city-03-checklist.md](./carpool-city-03-checklist.md) (Shared + iOS + E2E).

---

## Running the backend locally (iOS agent)

Use this when the Simulator (or a device on the same network) should call the API on your Mac. **You do not need Docker** for the default setup (SQLite file DB).

### Prerequisites

- **Node.js** LTS (v20 or newer is fine) — [nodejs.org](https://nodejs.org/) or `nvm`.

### Commands (from repository root)

```bash
cd server
npm install
npm run setup    # first time, or after backend DB schema / migrations change
npm run dev
```

- Default listen address: **`http://127.0.0.1:3000`** (or `http://0.0.0.0:3000` — use **127.0.0.1** in `API_BASE_URL` from Simulator).
- API base path: **`/v1`** → set the app to `http://127.0.0.1:3000/v1`.

### Verify it is up

```bash
curl -s http://127.0.0.1:3000/health
```

Expect JSON like `{"ok":true,"service":"carpool-api"}`. **`/health` is not under `/v1`.**

### Optional: `server/.env`

Copy [`server/.env.example`](../server/.env.example) to `server/.env` if you want to override defaults.

| Situation | What to know |
|-----------|----------------|
| **Nothing in `.env`** | Still works: **SQLite** at `server/prisma/dev.db`, **dev auth** (no Firebase Admin), **mock** geocode/routes if Maps key empty — good for UI work. |
| **Real Firebase ID tokens** | Backend needs Firebase **Admin** credentials + `DISABLE_AUTH=false`. See [`server/README.md`](../server/README.md). |
| **Real Google routes/geocoding** | Set `GOOGLE_MAPS_API_KEY` (Geocoding + Routes API enabled in Google Cloud). |
| **Port already in use** | Set `PORT=3001` (or another port) in `server/.env` and use the same port in `API_BASE_URL`. |

### More detail

- Full runbook, deploy notes, PostgreSQL option: **[`server/README.md`](../server/README.md)**  
- Demo flow ideas: **[`docs/DEMO.md`](./DEMO.md)**

---

## 1. What you must configure in the app

### 1.1 Base URL (`API_BASE_URL`)

All API paths below are **relative to** `API_BASE_URL`, which must include the **`/v1` prefix** (no trailing slash on the full base).

| Environment | Typical `API_BASE_URL` | Notes |
|-------------|------------------------|--------|
| **Simulator → Mac** | `http://127.0.0.1:3000/v1` | Backend default port is `3000` (`PORT` in `server/.env`). Use **127.0.0.1**, not `localhost`, if IPv6 causes issues. |
| **Physical iPhone → Mac** | `http://<your-mac-lan-ip>:3000/v1` | Same Wi‑Fi; firewall must allow inbound TCP on `PORT`. **App Transport Security:** for plain HTTP you need an **ATS exception** for that host (dev only) or use HTTPS (tunnel/ngrok, or deployed API). |
| **Production / demo** | `https://<your-deployed-host>/v1` | Railway, Render, etc. **HTTPS** avoids ATS problems on device. |

Example: `GET /me` → request URL = `API_BASE_URL` + `/me` → e.g. `http://127.0.0.1:3000/v1/me`.

### 1.2 Authentication header (every protected endpoint)

**All `/v1` endpoints require authentication.** Send on every request:

```http
Authorization: Bearer <token>
Content-Type: application/json
```

**Production (real users):**

1. Sign in with **Firebase Auth** (same Firebase **project** as `GoogleService-Info.plist`).
2. Obtain a **fresh ID token** (Firebase APIs such as `getIDToken()` / `getIDTokenForcingRefresh(true)` when needed).
3. Put that string in `Authorization: Bearer …`.

The backend verifies the token with **Firebase Admin** (service account on the server). The **Firebase client API key** in the plist is **not** sent to your API — only the **ID token**.

**Local dev (backend without Firebase Admin):**

- If the server runs with **auth verification off** (development default when Firebase credentials are missing), the backend still accepts `Authorization: Bearer <any-string>`.
- **Different strings ⇒ different synthetic users** (stable hash). Use this only for quick UI tests; for real E2E, run the server with **`DISABLE_AUTH=false`** and real Firebase Admin + real ID tokens.

**Missing / invalid token when auth is required:** **`401`** with `{ "error": "missing_bearer_token" }` or `{ "error": "invalid_token" }` — send the user to sign-in again or refresh the token.

### 1.3 `clientTimeZone` (required on bodies — do not skip)

For every request body that includes it, send the device’s **IANA** time zone id, same as the technical spec §10:

```swift
TimeZone.current.identifier   // e.g. "Europe/Zagreb", "America/New_York"
```

The server uses this for **application cutoff** (no new applications on/after **start of departure calendar day** in that zone) and **day-before cancel** rules. Wrong or missing values ⇒ wrong business behavior even if HTTP succeeds.

### 1.4 Date and time formats

| Field | Format | Example |
|-------|--------|---------|
| `departureDate` | Calendar date only **`YYYY-MM-DD`** (ISO date, UTC interpretation on server) | `"2026-04-15"` |
| `wantedArrivalAt` | **ISO 8601** instant (include offset or `Z`) | `"2026-04-15T09:00:00.000Z"` |

---

## 2. Intent status strings (drive your UI)

Use **exact** string equality (backend literals):

| `status` | Meaning for UI |
|----------|----------------|
| `collecting_passengers` | Open for applications; `seatsFilled < passengerSeats`. |
| `full_routing` | Car just filled; server computing route (short-lived). Show “Building route…” or poll `GET …/detail`. |
| `confirmed` | Route done; `stops[]` populated on detail. |
| `cancelled` | Intent ended. |

**Not yet implemented:** `in_progress` and `completed` (mentioned in the technical spec lifecycle but not in backend code for MVP). Treat any status not in this table as unknown / future.

---

## 3. Endpoints (method, path, body, responses)

Base path prefix: **`API_BASE_URL`** (already includes `/v1`).

### 3.1 `GET /me`

- **Auth:** required.  
- **Success `200`:** `{ "id": string, "displayName": string | null, "email": string | null }`  
- **Errors:** `401`.

### 3.2 `POST /driver-intents` — create driver intent

- **Auth:** required (driver).  
- **Body:**

```json
{
  "departureDate": "2026-04-15",
  "originAddress": "string",
  "destinationAddress": "string",
  "passengerSeats": 2,
  "clientTimeZone": "Europe/Zagreb"
}
```

- `passengerSeats`: integer **1…8**.  
- **Success `201`:** `{ "id", "status", "departureDate", "passengerSeats" }`  
- **Errors:** `400` (`validation_error`, `invalid_departure_date`), `401`.

### 3.3 `GET /driver-intents/mine`

- **Auth:** required.  
- **Query (optional):** `from`, `to` — each `YYYY-MM-DD` if you want to filter by `departureDate`.  
- **Success `200`:**  

```json
{
  "intents": [
    {
      "id": "uuid",
      "departureDate": "2026-04-15",
      "originAddress": "…",
      "destinationAddress": "…",
      "passengerSeats": 2,
      "status": "collecting_passengers",
      "seatsFilled": 1,
      "seatsRemaining": 1
    }
  ]
}
```

### 3.4 `DELETE /driver-intents/:id`

- **Auth:** required (must be owner driver).  
- **Success:** `204` No Content (also `204` if already cancelled).  
- **Errors:** `403` forbidden, `404` not found, `401`.

### 3.5 `POST /driver-intents/matches` — ranked intents for a rider

- **Auth:** required (rider; driver’s own intents are excluded from results).  
- **Body:**

```json
{
  "departureDate": "2026-04-15",
  "riderDepartureAddress": "string",
  "riderArrivalAddress": "string",
  "wantedArrivalAt": "2026-04-15T09:00:00.000Z",
  "clientTimeZone": "Europe/Zagreb"
}
```

- **Success `200`:** `{ "matches": [ { "intentId", "score", "driverDisplayName", "seatsRemaining", "departureDate", "originAddress", "destinationAddress" } ] }`  
- **Errors:** `409` `{ "error": "application_cutoff_passed" }`, `400`, `401`.

### 3.6 `POST /driver-intents/:intentId/applications` — rider applies

- **Auth:** required.  
- **Body:**

```json
{
  "riderDepartureAddress": "string",
  "riderArrivalAddress": "string",
  "wantedArrivalAt": "2026-04-15T09:00:00.000Z",
  "clientTimeZone": "Europe/Zagreb"
}
```

- **Success `201`:**  
  `{ "id", "intentId", "seatsFilled", "seatsTotal", "status", "routingStatus"? }`  
  - When the car **just filled**, `routingStatus` may be `"pending"` while status moves through `full_routing` to `confirmed`. Poll **`GET /driver-intents/:id/detail`** until `status === "confirmed"` or handle errors.

- **Errors `409`** — show a clear message; `error` field is stable for branching:

| `error` | Meaning |
|---------|---------|
| `intent_not_found` | Bad `intentId`. |
| `intent_cancelled` | |
| `intent_not_accepting_applications` | Already `confirmed` / routing. |
| `application_cutoff_passed` | Too late for this departure date (client TZ). |
| `cannot_apply_to_own_intent` | |
| `already_applied` | |
| `intent_full` | |
| `routing_failed` | Route infeasible; server rolls back the application — body may include `message`. |

### 3.7 `DELETE /applications/:id` — rider cancels application

- **Auth:** required (must own the application).  
- **Body (required):**

```json
{ "clientTimeZone": "Europe/Zagreb" }
```

- **Success:** `204`.  
- **Errors:** `409` `{ "error": "cancel_not_allowed_day_before_rule" }`, `403`, `404`, `400`, `401`.  
- If the intent was **`confirmed`**, cancel clears stops and sets status back to **`collecting_passengers`** (re-fill and re-route possible).

### 3.8 `GET /driver-intents/:id/detail`

- **Auth:** required; only **driver** or a rider with an **application** on that intent.  
- **Success `200`:**  
  - `id`, `status`, `departureDate`, `originAddress`, `destinationAddress`, `passengerSeats`  
  - `driver`: `{ id, displayName }`  
  - `applications[]`: `id`, `riderId`, `riderDisplayName`, `departureAddress`, `arrivalAddress`, `wantedArrivalAt`, `createdAt` (ISO strings)  
  - `stops[]`: `sequence`, `kind` (`pickup` | `dropoff`), `userId`, `placeLabel`, `latitude`, `longitude`, `scheduledAt` — populated when `status` is `confirmed` (may be empty while collecting).  
- **Errors:** `403` forbidden, `404` not found, `401`.

**Map:** Use `stops` coordinates and order for MapKit polylines or markers; encoded polyline is not guaranteed in the MVP JSON (legs come from server routing).

**Note:** `stops[]` does **not** include the driver's final destination — it ends at the last rider dropoff. To show the full route on a map, append the intent's `destinationAddress` (or geocode it client-side) as the last point after all stops.

---

## 4. HTTP status summary

| Code | Use |
|------|-----|
| `200` | OK (JSON body). |
| `201` | Created (JSON body). |
| `204` | Success, no body (`DELETE` intent/app). |
| `400` | Validation (`error`, optional `details`). |
| `401` | Auth missing/invalid. |
| `403` | Wrong user. |
| `404` | Not found. |
| `409` | Business conflict — read `error` (and optional `message`). |

Parse JSON error bodies for user-visible messages and analytics.

---

## 5. What the backend operator must provide (coordination)

For **your** iOS build to work **properly** against a **real** server (not dev mocks):

1. **Same Firebase project** as `GoogleService-Info.plist`.  
2. Server has **Firebase Admin** credentials (`FIREBASE_SERVICE_ACCOUNT_JSON` or `GOOGLE_APPLICATION_CREDENTIALS`) and **`DISABLE_AUTH=false`**.  
3. Server has **`GOOGLE_MAPS_API_KEY`** with **Geocoding API** and **Routes API** enabled (for real geocoding and routes).  
4. A reachable **base URL** (`https://…/v1` for devices in the field).

You do **not** paste the **Google server API key** into the iOS app — routing and geocoding stay on the backend.

---

## 6. Quick manual check (before deep UI work)

1. Backend running — see **Running the backend locally** above (or [`server/README.md`](../server/README.md)).  
2. `GET http://<host>:<port>/health` — health lives at the **server root** (e.g. `http://127.0.0.1:3000/health`), **not** under `/v1`. Derive host/port from your `API_BASE_URL` (drop the `/v1` suffix).  
3. Sign in → `GET …/v1/me` with Bearer ID token → `200`.  
4. Driver flow: create intent → mine.  
5. Second test user (second Firebase user or second dev bearer): matches → apply until full → detail shows `stops`.

---

## 7. Specs to keep aligned

- Product flows: [carpool-city-01-product.md](./carpool-city-01-product.md)  
- Full technical context: [carpool-city-02-technical.md](./carpool-city-02-technical.md) §10–§13, §17  
- Mark checklist **Shared**, **iOS**, **E2E** when verified: [carpool-city-03-checklist.md](./carpool-city-03-checklist.md)

If the backend changes status strings or error codes, update this file and the technical spec in the same PR.
