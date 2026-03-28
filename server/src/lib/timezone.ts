import { DateTime } from "luxon";

/**
 * Applications close when local time has reached the start of departure_date in clientTimeZone.
 */
export function isApplicationCutoffPassed(
  nowUtc: Date,
  departureDate: Date,
  clientTimeZone: string
): boolean {
  const dep = DateTime.fromJSDate(departureDate, { zone: "utc" }).startOf("day");
  const depY = dep.year;
  const depM = dep.month;
  const depD = dep.day;
  const startOfDepartureDay = DateTime.fromObject(
    { year: depY, month: depM, day: depD },
    { zone: clientTimeZone }
).startOf("day");
  const now = DateTime.fromJSDate(nowUtc, { zone: "utc" }).setZone(clientTimeZone);
  return now >= startOfDepartureDay;
}

/**
 * Cancel allowed only if local calendar date is strictly before departure_date (day-before policy).
 */
export function canCancelApplication(
  nowUtc: Date,
  departureDate: Date,
  clientTimeZone: string
): boolean {
  const dep = DateTime.fromJSDate(departureDate, { zone: "utc" }).startOf("day");
  const depY = dep.year;
  const depM = dep.month;
  const depD = dep.day;
  const departureLocal = DateTime.fromObject(
    { year: depY, month: depM, day: depD },
    { zone: clientTimeZone }
  ).startOf("day");
  const nowLocal = DateTime.fromJSDate(nowUtc, { zone: "utc" }).setZone(clientTimeZone).startOf("day");
  return nowLocal < departureLocal;
}

export function parseIsoDateOnly(s: string): Date {
  const d = DateTime.fromISO(s, { zone: "utc" });
  if (!d.isValid) throw new Error("invalid date");
  return new Date(Date.UTC(d.year, d.month - 1, d.day));
}
