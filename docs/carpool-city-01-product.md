# City Daily Commute Carpool — Product Vision & Requirements

This document describes **what** we are building and **why**, for engineers, designers, and agents implementing the app. It is the source of truth for product intent until revised here.

**Client platform (decided):** The product ships as a **native iOS application** (Swift / SwiftUI). There is **no Android or web client requirement** for MVP.

---

## 1. Problem statement

**Urban morning (and evening) congestion** hurts commuters, employers, and cities. Many people drive alone to work on **similar corridors and time windows**, which increases vehicles on the road for the same effective trips.

**Hypothesis:** If we make it **easy and reliable** to share rides **every day** within a **single city** (home → work and back), we can **reduce single-occupancy vehicles** for recurrent commute trips and ease peak-hour load—without asking people to coordinate manually in chat groups.

---

## 2. Product goal

Build a **carpooling application** optimized for **recurring, predictable commute** inside one city, where:

- People who **drive** **first** create a **morning intent to drive** (date, their commute inputs, and **how many passengers** they can take).
- People who **need a ride** enter **place of departure**, **place of arrival**, and **wanted time of arrival**; the app shows **which driver intents are the best match**; they **apply** to a chosen ride (same date).
- **For MVP there is no driver approval step:** applications are **accepted automatically** (e.g. first-come until seats are full—ordering policy is implementation detail).
- **When all passenger seats are filled**, the system **calculates the route and schedule** so **every rider arrives before their wanted time of arrival** (and the driver’s trip remains coherent—see technical spec).
- The experience is **repeatable** (daily / weekly rhythm), not only one-off long-distance rides.

**Non-goals for MVP:** In-app **payment** or fuel compensation logistics (people settle offline); **evening return** commute as a first-class product surface (morning-only for now—implementation may still stay general where cheap); **strict detour caps** or fine-grained fairness tuning; inter-city long haul as primary use case; freight; pure on-demand taxi-style pickup without planning.

---

## 3. Core user roles

| Role | Description |
|------|-------------|
| **Rider (passenger)** | Provides **place of departure** (e.g. home), **place of arrival** (e.g. work), and **wanted time of arrival** (deadline at the destination). Sees **ranked best-matching** driver intents, then **applies** to one. Pickup order/time come from the **computed route** once the car is full. |
| **Driver** | Creates an **intent to drive** in the morning (date + commute inputs + **passenger seat count**). Riders **apply**; **no driver “accept” step in MVP**. Once seats are **full**, the system outputs **route/stops/times**. |

**Decided:** A **single account** may act as **driver or rider** depending on what they choose for a given trip (option: “I’m driving” vs “I need a ride”—no duplicate identities).

---

## 4. Primary user journeys

### 4.1 Driver (has a car) — happens first

1. User selects **driving**.
2. Creates **morning intent to drive**: date, driver’s addresses/route inputs per technical spec, and **number of passenger seats** offered.
3. The driver **fills a creation form** first (draft locally). **Publishing** the ride (primary confirm in the client) is when the intent becomes **open for applications** until passenger seats are **filled**. The reference iOS model uses `isPublished` on `ScheduledRide` for visibility to passengers once a backend exists; until then this is client-only state.

### 4.2 Rider (needs a ride) — match, then apply

1. User selects **being driven**.
2. Enters **place of departure**, **place of arrival**, **wanted time of arrival**, and the **date** (morning commute).
3. The app shows **driver intents that are the best match** for that trip (ordering/scoring is an implementation detail—see technical spec).
4. User **applies** to **one** chosen intent. Application is recorded **without driver approval** (MVP).
5. User sees **status** such as: **waiting for seats** (car not full yet) → **route being planned** (optional transient) → **confirmed** with **stops and times** once the car is full and routing has run. **Cancelled** / **in progress** / **completed** as appropriate.

### 4.3 When the car is full

1. As soon as **applied riders == available passenger seats**, the system **runs route calculation** so everyone (driver + riders) gets a **single coordinated plan**: order of pickups/dropoffs and times such that **each rider reaches their arrival point before their wanted time of arrival** (pickup times vary per person).
2. Driver and all riders see the **final route and schedule**.

**MVP note:** Trips that **never fill** all seats do not get a computed route in this story; **partial carpools or “close early”** can be a later iteration.

States should remain clear end-to-end: **collecting riders** → **full → route computed → confirmed** → in progress → completed / cancelled.

---

## 5. Commute context (city, recurrence, time)

- **Geography:** **Inside one city** (or metro). Use **exact addresses** for homes and workplaces; on-device **map and address UI** follow iOS patterns; server-side routing/display details use **Google Maps** APIs (see technical spec).
- **Recurrence:** Everyday commute mindset—users may repeat patterns on weekdays or selected days.
- **Time sensitivity:** For MVP, **every rider must arrive before their stated wanted time of arrival** (for commute this is effectively “start of work”). **Departure from home is not fixed globally**—the **route and schedule are computed once the car is full** so **constraints** are satisfied collectively (no strict published detour limits for MVP; focus on feasibility + simplicity).

---

## 6. Matching & sequencing (MVP decisions)

| Topic | Decision |
|--------|-----------|
| **Sequence** | **Driver intent first** → riders **apply** to that intent (or equivalent linkage) → **no driver acceptance** in MVP. |
| **When routing runs** | **After all passenger seats are filled** (applications recorded == capacity). Then compute **route + stop order + times**. |
| **Who is in the car** | Whoever has **successfully applied** up to **seat limit** (MVP: define tie-break / ordering as **FCFS** or simplest fair rule in tech spec). |
| **Driver veto** | **Not in MVP** (no accept/reject for driver). |
| **Detour / limits** | **No strict detour rules** for MVP; correctness anchor is **on-time arrival** per rider’s **wanted time of arrival** once the group is fixed. |
| **Rider discovery** | Rider enters **departure**, **arrival**, **wanted time of arrival**, **date** → app lists **best-matching** open driver intents; rider picks one and **applies**. |
| **Inputs** | **Exact addresses** + **wanted arrival time** per applicant (same field role as former “work start”); driver intent fields per technical spec. |
| **Fairness / edge cases** | Partial fill / unfilled cars: **no route** in MVP; waitlists and re-matching **phase 2**. |

Engineering: **state machine** should include **filling seats** vs **full / routing** vs **confirmed**; keep routing **idempotent** when run once at “full.”

---

## 7. Trust, safety, and identity (minimum bar)

For real daily use, the app must address **basic trust**:

- **Accounts** tied to a stable identity (e.g. phone/email; stronger verification later).
- **Profiles** showing name, photo (optional policy), and simple **reputation** when added.
- **In-trip support:** **cancel** (see §8), **report**, and **contact** matched users within policy.

Exact verification level (ID, employer email) remains **TBD**.

---

## 8. Cancellation, reopening & cutoff (MVP)

**Canceling a spot:** A user may **cancel no later than the day before** the trip (same simple policy as before; e.g. no same-day cancels unless you refine later).

**When someone cancels:** The **seat reopens**. **New applications** (or anyone filling that seat) are allowed **until 00:00 on the day of departure**—i.e. **once the departure calendar day starts in the user’s locale, the car is closed to new riders**. **Decided:** use each user’s **device locale / local calendar** (e.g. iOS system time zone) to interpret **which calendar day** the trip is on and when that day begins.

**If the car was already “full” and a route existed** when someone cancels: **MVP** treats the pool as **not complete** again—**drop the previous computed route** for that intent, go back to **collecting passengers**, and **run routing again** only after all seats are **full** once more (still before any stricter locks you add later).

Detailed penalties, no-shows, and richer same-day rules are **out of scope for MVP**.

---

## 9. Scope: morning vs evening

- **Product focus for MVP:** **Morning commute only.**
- **Implementation:** Prefer designs that **do not hard-code** “morning only” everywhere if the cost is low, but **evening return** is **not** a required MVP feature.

---

## 10. Payments & incentives (MVP)

- **No in-app payment** for MVP.
- **Assumption:** Riders and drivers **arrange fuel/compensation outside the app**; the product **does not** track money, split costs, or enforce payment.

**Later:** in-app cost sharing, employer programs, incentives.

---

## 11. Success metrics (directional)

- **Trips completed** per week (recurring).
- **Average occupancy** per commute trip (riders per car).
- **Repeat usage** (same user active multiple days/weeks).
- **On-time arrival** (each rider before their **wanted time of arrival**, where measurable).

---

## 12. MVP summary (checklist for builders)

- [ ] One city / metro configuration (or unconstrained MVP geography with addresses).
- [ ] User can choose **driver** vs **rider** per flow; one account.
- [ ] Rider: **departure**, **arrival**, **wanted time of arrival**, date → **best-match driver list** → **apply** to one intent.
- [ ] Driver: **morning intent to drive** + passenger **seat count**; intent **open for applications**.
- [ ] Riders: **no driver approval** (MVP).
- [ ] When seats **full**: **route/schedule** computed so all arrive before respective **wanted arrival** times.
- [ ] **Unfilled** intents: no final route in MVP (partial carpool **later**).
- [ ] **Cancel day-before**; **reopen** seat until **start of departure day** (each user’s **device locale** / local calendar) for new applications; **re-route** if full set changes after a prior route existed.
- [ ] **No** in-app payment; **morning-only** product scope.
- [ ] **iOS** app: notifications + trip detail UI (maps integration per technical spec).

---

## 13. Document ownership

- **This file** is the **product / context** anchor.
- **[carpool-city-02-technical.md](./carpool-city-02-technical.md)** turns decisions here into **implementation and technology** choices.
- **[carpool-city-03-checklist.md](./carpool-city-03-checklist.md)** tracks **what is implemented and verified** (iOS vs backend owners, integration, E2E demo). Checklist items should be marked complete only after **manual verification**, not only after merge.
- **[AGENT_INSTRUCTIONS.md](./AGENT_INSTRUCTIONS.md)** explains **how agents and devs** should use these three files and the checklist, including the **two-agent** split (**backend** vs **frontend iOS**).

When product answers change, update **this file first**, then adjust the technical spec and checklist accordingly.
