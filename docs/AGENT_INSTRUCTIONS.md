# Instructions for agents & developers

Use this file together with the three planning documents for the city carpool MVP. It tells you **how** to work with them, not **what** the product is (that lives in the other files).

---

## Two agents (recommended split)

Implementation is designed for **two parallel agents** (or two human devs) with a clean boundary:

| Agent | Scope | Primary doc sections |
|--------|--------|----------------------|
| **Backend agent** | Node.js + TypeScript + **Fastify** API, **PostgreSQL**, **Firebase Admin** (token verify), **Google** Geocoding + **Routes API**, match/rank + routing logic, deploy (e.g. Railway/Render) | [Technical §3, §10–§16](./carpool-city-02-technical.md), checklist **Investigation**, **Shared** (with frontend), **Backend** |
| **Frontend agent** | **iOS SwiftUI** app, **Firebase Auth** (sign-in), **URLSession** API client, all screens and map UX, sends **`clientTimeZone`** + bodies per **§12** | [Technical §12, §17](./carpool-city-02-technical.md), **[IOS_BACKEND_INTEGRATION.md](./IOS_BACKEND_INTEGRATION.md)** (concrete API usage), [Product §4](./carpool-city-01-product.md), checklist **Shared** (with backend), **iOS** |

**Both** must coordinate on **Shared** and **End-to-end** in [carpool-city-03-checklist.md](./carpool-city-03-checklist.md) before calling the MVP done.

If only **one** agent runs, it should still follow the same checklist sections in order: backend foundation → frontend foundation → integration → E2E.

---

## The three documents (order of truth)

| File | Role | When to read it |
|------|------|------------------|
| [carpool-city-01-product.md](./carpool-city-01-product.md) | **What** we are building: user journeys, MVP rules, cancellations, scope. | Before any feature work; when product intent is unclear. |
| [carpool-city-02-technical.md](./carpool-city-02-technical.md) | **How** we implement: stack (iOS, Fastify, Firebase, Routes API), schema, REST API, routing behavior. | When writing or reviewing code; when designing endpoints or DB changes. |
| [carpool-city-03-checklist.md](./carpool-city-03-checklist.md) | **What is done and verified**: tasks for **backend agent**, **frontend (iOS) agent**, plus **Shared** and **E2E**. | During implementation; before claiming a milestone is complete. |

**Rule:** If product and technical specs disagree, **product wins until humans update the technical spec**. If code disagrees with both, **fix the code** or **propose a doc change** explicitly—do not silently drift.

---

## How to use the checklist ([carpool-city-03-checklist.md](./carpool-city-03-checklist.md))

### Checkboxes

- **`[ ]`** — Not started (default).
- **`[~]`** — In progress (optional; use when a task spans multiple commits).
- **`[x]`** — **Only** when the item is **implemented and manually verified** (API tested, iOS flow tested, or E2E scenario passed). Do **not** mark `[x]` on “merged PR only.”

### Sections and ownership (maps to the two agents)

- **Investigation — Google Routes API** — **Backend agent** owns this spike; frontend agent may read summaries only.
- **Shared / integration** — **Both agents** (backend + frontend): API contract, Firebase, deploy URL, error codes. Nothing ships without alignment here.
- **Backend** — **Backend agent** checklist only: server, DB, Google, REST §12.
- **iOS** — **Frontend agent** checklist only: SwiftUI, Auth, API client, UI from product §4.
- **End-to-end** — **Both agents** verify together against a **real** API + Firebase.

If your Cursor session is scoped as **one** agent, say so in chat: *“Act as the backend agent”* or *“Act as the frontend (iOS) agent”* and work the matching checklist sections first; still skim Shared so you do not block the other side.

### After you complete work

1. Update the checklist: set the right items to `[x]` or `[~]`.
2. Add a short entry to the **Verification log** table (date, who, what was tested).
3. If you changed behavior (new endpoint, status name, cutoff rule), update **carpool-city-02-technical.md** (and **carpool-city-01-product.md** if it is a product-visible change).

---

## Workflow for agents implementing features

1. Read the relevant **product** section (journeys, §6–8 for rules).
2. Read the matching **technical** section (§10–§17 for API, time zones, Routes API, iOS structure).
3. Implement in **small steps**; keep API shapes aligned with technical **§12**.
4. Run **manual verification** matching an **E2E** row where possible.
5. Update **carpool-city-03-checklist.md** and optionally link a PR or commit in the verification log.

---

## When the user changes product or stack

1. Edit **carpool-city-01-product.md** first (if the change is “what”).
2. Edit **carpool-city-02-technical.md** second (schemas, endpoints, Google usage).
3. Add or reorder tasks in **carpool-city-03-checklist.md** so “everything works” when all boxes are `[x]`.
4. Do not leave stale checklist items that contradict the other two files.

---

## Quick links

- **iOS ↔ API (base URL, auth, every endpoint, errors):** [IOS_BACKEND_INTEGRATION.md](./IOS_BACKEND_INTEGRATION.md)

- Product MVP summary: [carpool-city-01-product.md §12](./carpool-city-01-product.md)
- REST API draft: [carpool-city-02-technical.md §12](./carpool-city-02-technical.md)
- DB schema: [carpool-city-02-technical.md §11](./carpool-city-02-technical.md)
- Status enum: [carpool-city-02-technical.md §13](./carpool-city-02-technical.md)
- Time zone contract: [carpool-city-02-technical.md §10](./carpool-city-02-technical.md)
- Routes API decisions (after investigation): [carpool-city-02-technical.md §14.1](./carpool-city-02-technical.md)

---

## Scope

These instructions apply to **this repo’s carpool MVP** documented in the three `carpool-city-*.md` files. For unrelated code in the repo, follow normal project conventions unless the user says otherwise.
