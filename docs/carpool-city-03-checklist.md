# City Daily Commute Carpool — Implementation Checklist

Tracks **completed work** against [carpool-city-01-product.md](./carpool-city-01-product.md) (what) and [carpool-city-02-technical.md](./carpool-city-02-technical.md) (how). When **every** item below is `[x]` and verified, the MVP demo path in those documents is satisfied.

**Two agents:** Use **one backend agent** (Fastify, DB via Prisma — **SQLite by default** locally; PostgreSQL on Railway/Render when configured; **Firebase Admin**; **Google Routes API**) and **one frontend agent** (iOS SwiftUI, Firebase Auth, API client, UI). See [AGENT_INSTRUCTIONS.md § Two agents](./AGENT_INSTRUCTIONS.md#two-agents-recommended-split).

**Broader guidance:** [AGENT_INSTRUCTIONS.md](./AGENT_INSTRUCTIONS.md) for how to use all planning `.md` files together.

---

## How to use this checklist (human devs & agents)

1. **Ownership:** Two roles — **Backend agent** vs **Frontend (iOS) agent**. Fill in names under each section header (`Primary owner`).
2. **Mark progress honestly:**
   - `[ ]` = not started  
   - `[~]` = in progress  
   - `[x]` = **implemented *and* verified working** (manual test on device/simulator or against deployed API; not “code merged only”).
3. When you check `[x]`, add a **short note** on the same line or in **Verification log** at the bottom: e.g. initials + date, PR link, or “tested: driver intent → 2 riders → full → route”.
4. **Do not** mark integration or E2E items `[x]` until **both sides** have agreed the flow works against the **real** deployed backend URL (or local tunnel) and **real** Firebase project.
5. If product/spec changes, update [carpool-city-01-product.md](./carpool-city-01-product.md) / [carpool-city-02-technical.md](./carpool-city-02-technical.md) first, then adjust this file.

**Legend:** `[ ]` not started · `[~]` in progress · `[x]` done **and** verified

### Implementation snapshot (2026-03-28)

| Area | Status |
|------|--------|
| **Backend (`server/`)** | MVP REST, SQLite-by-default local DB, Prisma migrations, fill-triggered routing (`computeRoutes` + Geocoding when a Maps key is set; **deterministic mocks** when the key is empty), dev auth when Firebase is unset, `docs/DEMO.md` + `server/README.md` updated. |
| **Gaps vs spec** | Match ranking does **not** use **`computeRouteMatrix`** yet (haversine after geocode, or seats-left heuristic without a key). **§14.1** in the technical doc is still a stub. **PostgreSQL** is not the default local DB (SQLite file); production Postgres requires changing Prisma `provider` + URL. |
| **iOS** | Not tracked as implemented in this pass (existing Xcode project; wire to API separately). |
| **E2E / deploy** | Not marked complete here — add rows to **Verification log** when you run the demo path on device/simulator against a real URL. |

*Below, backend items marked `[x]` mean **implemented in `server/`** and aligned with [technical §12](./carpool-city-02-technical.md) unless noted. Per the rules above, treat **Verification log** as the source of truth for “tested on device / deployed API.”*

---

## Product coverage map

These MVP outcomes from [carpool-city-01-product.md](./carpool-city-01-product.md) are covered by the tasks below:

| Product requirement | Where in checklist |
|---------------------|-------------------|
| Driver intent first + seat count | Backend driver intents, iOS driver flow |
| Rider: departure / arrival / wanted arrival / date → best match → apply | Match API + iOS rider flow Integration |
| Auto applications, no driver approval | (implicit—no driver-accept tasks) |
| Route when full; unfilled = no route | Backend on-fill routing + iOS states |
| Day-before cancel; reopen until start departure day (locale); re-route after dropout | Backend cancel/cutoff + iOS cancel |
| Morning-only, no payment | Out of scope items omitted |
| iOS native | iOS section |
| Trust: account, profile, cancel | Auth + `GET /me` + iOS profile; report/contact **optional** for MVP (stub OK) |
| Routes API usage (how we call Google) | **Investigation — Google Routes API** (below) |

---

## Investigation — Google Routes API in this app

*Primary owner: **Backend agent** (frontend agent may skim only). Mark `[x]` when the item is **done and findings are recorded** in [carpool-city-02-technical.md](./carpool-city-02-technical.md) (e.g. new subsection under §14 or a short **§14.1 Routes API — implementation decisions**). These are **research/spike** tasks, not production E2E.*

- [~] Read [Routes API overview](https://developers.google.com/maps/documentation/routes) and the exact methods we need: **`computeRoutes`** (waypoints / intermediates, polyline, legs) and **`computeRouteMatrix`** (many O×D in one request, [limits](https://developers.google.com/maps/documentation/routes/route_matrix)) — *`computeRoutes` is in code; matrix not used for ranking yet*
- [~] Confirm **authentication** for server-side calls: API key restrictions (IP / referrer), optional OAuth for Routes; never expose unrestricted keys in iOS — *keys only on server; restriction policy not written up in §14.1*
- [ ] **Match ranking (§15):** decide how **`computeRouteMatrix`** is used—e.g. rider home → driver route corridor vs rider home → work vs driver O/D; how to stay within **element limits** when many open intents exist (batch, cap list, or simplify heuristic) — *current code: haversine / geocode proximity, not matrix*
- [~] **Full car route (§16):** decide how **`computeRoutes`** is used once stop **order** is chosen—`intermediates` order, `routingPreference`, traffic vs no traffic for MVP, how **encoded polyline** is returned and stored for the app — *implemented: FCFS pickup/drop order, `TRAFFIC_UNAWARE`, polyline optional/not persisted on `ride_stops`*
- [x] **Geocoding → Routes:** confirm pipeline: address strings → lat/lng (Geocoding) → Routes requests use **Waypoint** / lat-lng as required by API version — *see `server/src/lib/googleMaps.ts` + `routingService.ts`*
- [~] Run a **spike** (curl, Postman, or small Node script): at least one successful **`computeRoutes`** with multiple intermediates; at least one **`computeRouteMatrix`** response parsed — *computeRoutes path exercised via API when key set; matrix spike not done*
- [ ] **Quota/cost:** note expected calls per “match search” and per “car full” route; document in technical spec so demos do not burn billing
- [ ] **Summarize** in **technical spec**: paste example request/response shapes (redacted) or link to internal doc; update §15–§16 if the investigation changes the planned heuristics — *§14.1 still “fill in after spike”*

---

## Shared — integration & contract

*Both agents (backend + frontend); blocking for a real demo.*

- [~] **API contract** agreed: paths & bodies match [technical spec §12](./carpool-city-02-technical.md); **`departureDate`** + **`clientTimeZone`** (IANA) on every request that needs cutoff logic [§10](./carpool-city-02-technical.md) — *backend implements §12; iOS client DTOs need confirmation*
- [~] **Firebase:** one project; iOS has `GoogleService-Info.plist`; backend has Admin credentials in env (e.g. `GOOGLE_APPLICATION_CREDENTIALS` or JSON secret) — *backend supports Admin + **dev mode without Firebase** (`server/README.md`); full stack TBD*
- [ ] **Deployed API** has public **HTTPS** base URL (e.g. Railway/Render); iOS **Debug/Release** `API_BASE_URL` points to it
- [x] **Status strings** align with [technical §13](./carpool-city-02-technical.md) (`collecting_passengers`, `full_routing`, `confirmed`, `cancelled`) so iOS can branch UI — *backend uses these literals*
- [ ] **Error handling contract:** iOS parses `401` / `409` (capacity, cutoff, duplicate apply, routing failure) with user-visible messages

---

## Backend agent — Node.js + TypeScript + Fastify

*Primary owner (backend agent): \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_*

### Foundation

- [x] Repo/service bootstrapped: Fastify, TypeScript, `pnpm`/`npm` scripts (`dev`, `build`, `start`, `setup`, `postinstall` Prisma generate)
- [x] Database + migrations for schema [technical §11](./carpool-city-02-technical.md) (`users`, `driver_intents`, `rider_applications`, `ride_stops`) — **default local: SQLite** `file:./prisma/dev.db`; PostgreSQL requires Prisma `provider` + `DATABASE_URL` change for deploy
- [x] **Firebase Admin** middleware: verify `Authorization: Bearer <Firebase ID token>`; upsert `users` row by Firebase `uid` on first request — *plus dev: synthetic users from bearer string when Firebase unset; see `server/src/config.ts`*
- [x] `GET /health` (or `/v1/health`) for deploy checks — *`GET /health` at root*
- [x] Env vars documented: `DATABASE_URL`, Maps key(s), Firebase Admin, optional `LOG_LEVEL` — *see `server/.env.example`, `server/README.md`*

### Google Maps (server-side)

- [x] **Geocoding** used where lat/lng needed for Routes API — *mock lat/lng in development when key empty*
- [ ] **Routes API:** `computeRouteMatrix` (or equivalent) for **match ranking** heuristic [§15](./carpool-city-02-technical.md) — *not implemented; haversine + optional geocode*
- [x] **Routes API:** `computeRoutes` for **final** ordered stops after car is full [§16](./carpool-city-02-technical.md) — *mock legs when key empty*
- [x] Stops persisted to `ride_stops`; intent status `confirmed` when routing succeeds
- [~] Keys only on server; quota/billing understood — *server-only yes; quota notes not added to technical spec*

### REST API [§12](./carpool-city-02-technical.md)

- [x] `GET /v1/me` — returns profile for authenticated user
- [x] `POST /v1/driver-intents` — create intent (`departureDate`, addresses, `passengerSeats`, `clientTimeZone`)
- [x] `GET /v1/driver-intents/mine` — driver’s intents
- [x] `DELETE /v1/driver-intents/:id` — cancel intent per policy
- [x] `POST /v1/driver-intents/matches` — ranked open intents for rider query
- [x] `POST /v1/driver-intents/:intentId/applications` — apply; **transactional** cap **K**; **FCFS**; reject if after cutoff (start of departure local day)
- [x] `DELETE /v1/applications/:id` — rider withdraws; **day-before** cancel rule enforced; reopen seat; if was `confirmed`, **delete stops**, status → `collecting_passengers`
- [x] `GET /v1/driver-intents/:id/detail` — driver + applicants only; includes `applications[]`, `stops[]` when confirmed
- [x] **On last application filling car:** trigger routing (inline OK); handle **no feasible route** [§16](./carpool-city-02-technical.md) without corrupting data — *409 `routing_failed`, last application rolled back, status restored to `collecting_passengers`*

### Non-functional [technical §8]

- [x] No **overfill** (DB unique + transaction)
- [ ] Rate limit or basic abuse protection on expensive endpoints (optional but recommended)
- [~] Structured logging; **no** full addresses in info logs — *Fastify logger on; audit for PII in logs if needed*

### Push (optional for bare MVP; required for “product complete” demo)

- [ ] **FCM** or direct **APNs** from backend: notify on apply, car full / route ready, cancel — *not implemented; polling-only demo documented in `docs/DEMO.md`*

---

## Frontend agent — iOS SwiftUI

*Primary owner (frontend / iOS agent): \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_*

### Foundation

- [ ] Xcode project builds; app entry + configuration for **`API_BASE_URL`**
- [ ] **Firebase Auth** integrated; sign-in/sign-out; obtain **ID token** for API calls
- [ ] **API client** (`URLSession`): sets `Authorization` header; encodes/decodes DTOs matching [§12](./carpool-city-02-technical.md)
- [ ] Every required call sends **`clientTimeZone`** = `TimeZone.current.identifier` [§10](./carpool-city-02-technical.md)
- [ ] **Keychain or secure** storage not required if using Firebase token refresh each session—pick one consistent approach

### UX — product flows

- [ ] After login: **mode** “I’m driving” vs “I need a ride” [product §3–4](./carpool-city-01-product.md)
- [ ] **Driver:** form — `departureDate`, origin, destination, `passengerSeats` → `POST` intent → list **my intents** with **seats filled / status**
- [ ] **Rider:** form — departure, arrival, **wanted time of arrival**, date → `POST` matches → list **ranked** intents → **apply** to one
- [ ] **Trip / intent detail:** show status pipeline (**collecting** → **routing** → **confirmed**); show **stops + times** + map when available
- [ ] **Map:** MapKit (or Maps SDK) shows route/stops from API (polyline or coordinates from backend)
- [ ] **Cancel:** rider/driver cancel flows; show errors when **day-before** or **cutoff** forbids action
- [ ] **Empty / error states:** no matches, how routing failed (`409`), intent never fills [product §12](./carpool-city-01-product.md)
- [ ] **No** driver accept/reject UI (MVP)

### polish

- [ ] Basic loading indicators and retry where appropriate
- [ ] **Push** registration wired if backend sends notifications; else periodic refresh on trip screens

---

## End-to-end — demo must pass

*Both agents together; all `[x]` means MVP demo is honest.*

- [ ] **E2E 1 — Happy path:** Driver creates intent (**K**≥2) → **K** riders apply (same date, valid addresses) → all see **confirmed** + **stops** + map
- [ ] **E2E 2 — Cutoff:** Verify new **application** rejected after **start of departure day** in test timezone (adjust device or test user TZ)
- [ ] **E2E 3 — Cancel / reopen:** Rider cancels **day before** → seat reopens → another rider applies → car can go **full** and route again
- [ ] **E2E 4 — Dropout after confirm:** Cancel when previously **confirmed** → **stops** cleared, status **collecting**, **re-fill** + **re-route** works
- [ ] **E2E 5 — Auth:** Invalid/expired token → **401**; iOS sends user to sign-in

---

## Quality & release (either agent)

- [~] Backend lint/test (if configured); iOS build **Archive** succeeds — *`npm run build` (tsc) passes for `server/`; no ESLint wired*
- [x] README or **docs/DEMO.md**: how to run API + iOS, env vars, test accounts — *`server/README.md`, `docs/DEMO.md`*

---

## Verification log

*(Append a row each time you complete an E2E scenario or milestone.)*

| Date | Who | What was verified |
|------|-----|-------------------|
| 2026-03-28 | Backend impl | Checklist updated to match `server/` codebase (SQLite default, REST §12, routing/mocks). E2E on device/simulator not claimed here. |
| | | |

---

## Notes

- **Report / contact matched users** [product §7](./carpool-city-01-product.md): not required for checklist completion; stub button or omit for hackathon.
- Technical **§18** references this file; keep sections in sync when adding endpoints.
    