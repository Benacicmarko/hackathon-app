# City Daily Commute Carpool — Implementation Checklist

Tracks **completed work** against [carpool-city-01-product.md](./carpool-city-01-product.md) (what) and [carpool-city-02-technical.md](./carpool-city-02-technical.md) (how). When **every** item below is `[x]` and verified, the MVP demo path in those documents is satisfied.

**Two agents:** Use **one backend agent** (Fastify, Postgres, Firebase Admin, Google Routes API) and **one frontend agent** (iOS SwiftUI, Firebase Auth, API client, UI). See [AGENT_INSTRUCTIONS.md § Two agents](./AGENT_INSTRUCTIONS.md#two-agents-recommended-split).

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

- [ ] Read [Routes API overview](https://developers.google.com/maps/documentation/routes) and the exact methods we need: **`computeRoutes`** (waypoints / intermediates, polyline, legs) and **`computeRouteMatrix`** (many O×D in one request, [limits](https://developers.google.com/maps/documentation/routes/route_matrix))
- [ ] Confirm **authentication** for server-side calls: API key restrictions (IP / referrer), optional OAuth for Routes; never expose unrestricted keys in iOS
- [ ] **Match ranking (§15):** decide how **`computeRouteMatrix`** is used—e.g. rider home → driver route corridor vs rider home → work vs driver O/D; how to stay within **element limits** when many open intents exist (batch, cap list, or simplify heuristic)
- [ ] **Full car route (§16):** decide how **`computeRoutes`** is used once stop **order** is chosen—`intermediates` order, `routingPreference`, traffic vs no traffic for MVP, how **encoded polyline** is returned and stored for the app
- [ ] **Geocoding → Routes:** confirm pipeline: address strings → lat/lng (Geocoding) → Routes requests use **Waypoint** / lat-lng as required by API version
- [ ] Run a **spike** (curl, Postman, or small Node script): at least one successful **`computeRoutes`** with multiple intermediates; at least one **`computeRouteMatrix`** response parsed
- [ ] **Quota/cost:** note expected calls per “match search” and per “car full” route; document in technical spec so demos do not burn billing
- [ ] **Summarize** in **technical spec**: paste example request/response shapes (redacted) or link to internal doc; update §15–§16 if the investigation changes the planned heuristics

---

## Shared — integration & contract

*Both agents (backend + frontend); blocking for a real demo.*

- [ ] **API contract** agreed: paths & bodies match [technical spec §12](./carpool-city-02-technical.md); **`departureDate`** + **`clientTimeZone`** (IANA) on every request that needs cutoff logic [§10](./carpool-city-02-technical.md)
- [ ] **Firebase:** one project; iOS has `GoogleService-Info.plist`; backend has Admin credentials in env (e.g. `GOOGLE_APPLICATION_CREDENTIALS` or JSON secret)
- [ ] **Deployed API** has public **HTTPS** base URL (e.g. Railway/Render); iOS **Debug/Release** `API_BASE_URL` points to it
- [ ] **Status strings** align with [technical §13](./carpool-city-02-technical.md) (`collecting_passengers`, `full_routing`, `confirmed`, `cancelled`) so iOS can branch UI
- [ ] **Error handling contract:** iOS parses `401` / `409` (capacity, cutoff, duplicate apply, routing failure) with user-visible messages

---

## Backend agent — Node.js + TypeScript + Fastify

*Primary owner (backend agent): \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_*

### Foundation

- [ ] Repo/service bootstrapped: Fastify, TypeScript, `pnpm`/`npm` scripts (`dev`, `build`, `start`)
- [ ] PostgreSQL reachable via `DATABASE_URL`; migrations applied for schema [technical §11](./carpool-city-02-technical.md) (`users`, `driver_intents`, `rider_applications`, `ride_stops`)
- [ ] **Firebase Admin** middleware: verify `Authorization: Bearer <Firebase ID token>`; upsert `users` row by Firebase `uid` on first request
- [ ] `GET /health` (or `/v1/health`) for deploy checks
- [ ] Env vars documented: `DATABASE_URL`, Maps key(s), Firebase Admin, optional `LOG_LEVEL`

### Google Maps (server-side)

- [ ] **Geocoding** used where lat/lng needed for Routes API
- [ ] **Routes API:** `computeRouteMatrix` (or equivalent) for **match ranking** heuristic [§15](./carpool-city-02-technical.md)
- [ ] **Routes API:** `computeRoutes` for **final** ordered stops after car is full [§16](./carpool-city-02-technical.md)
- [ ] Stops persisted to `ride_stops`; intent status `confirmed` when routing succeeds
- [ ] Keys only on server; quota/billing understood

### REST API [§12](./carpool-city-02-technical.md)

- [ ] `GET /v1/me` — returns profile for authenticated user
- [ ] `POST /v1/driver-intents` — create intent (`departureDate`, addresses, `passengerSeats`, `clientTimeZone`)
- [ ] `GET /v1/driver-intents/mine` — driver’s intents
- [ ] `DELETE /v1/driver-intents/:id` — cancel intent per policy
- [ ] `POST /v1/driver-intents/matches` — ranked open intents for rider query
- [ ] `POST /v1/driver-intents/:intentId/applications` — apply; **transactional** cap **K**; **FCFS**; reject if after cutoff (start of departure local day)
- [ ] `DELETE /v1/applications/:id` — rider withdraws; **day-before** cancel rule enforced; reopen seat; if was `confirmed`, **delete stops**, status → `collecting_passengers`
- [ ] `GET /v1/driver-intents/:id/detail` — driver + applicants only; includes `applications[]`, `stops[]` when confirmed
- [ ] **On last application filling car:** trigger routing (inline OK); handle **no feasible route** [§16](./carpool-city-02-technical.md) without corrupting data

### Non-functional [technical §8]

- [ ] No **overfill** (DB unique + transaction)
- [ ] Rate limit or basic abuse protection on expensive endpoints (optional but recommended)
- [ ] Structured logging; **no** full addresses in info logs

### Push (optional for bare MVP; required for “product complete” demo)

- [ ] **FCM** or direct **APNs** from backend: notify on apply, car full / route ready, cancel — *if skipped, document “polling only” for demo*

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

- [ ] Backend lint/test (if configured); iOS build **Archive** succeeds
- [ ] README or **docs/DEMO.md**: how to run API + iOS, env vars, test accounts

---

## Verification log

*(Append a row each time you complete an E2E scenario or milestone.)*

| Date | Who | What was verified |
|------|-----|-------------------|
| | | |

---

## Notes

- **Report / contact matched users** [product §7](./carpool-city-01-product.md): not required for checklist completion; stub button or omit for hackathon.
- Technical **§18** references this file; keep sections in sync when adding endpoints.
