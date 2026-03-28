import { DateTime } from "luxon";
import type { DriverIntent, RiderApplication, User } from "@prisma/client";
import { geocodeAddress, computeRoute, type LatLng } from "../lib/googleMaps.js";
import { prisma } from "../lib/prisma.js";

type AppWithRider = RiderApplication & { rider: User };

export const STATUS = {
  collecting: "collecting_passengers",
  routing: "full_routing",
  confirmed: "confirmed",
  inProgress: "in_progress",
  cancelled: "cancelled",
} as const;

/**
 * Driver origin → rider pickups (FCFS) → rider dropoffs (FCFS) → driver destination.
 * Route start anchor: 07:00 local on departure day (`timeZone` from first rider application).
 */
export async function buildAndPersistRoute(
  intent: DriverIntent,
  applications: AppWithRider[]
): Promise<void> {
  const K = intent.passengerSeats;
  if (applications.length !== K) {
    throw new Error(`expected ${K} applications, got ${applications.length}`);
  }

  const sorted = [...applications].sort(
    (a, b) => a.createdAt.getTime() - b.createdAt.getTime()
  );
  const timeZone = sorted[0]?.clientTimeZone || "UTC";

  const dep = DateTime.fromJSDate(intent.departureDate, { zone: "utc" }).startOf("day");
  const routeStart = DateTime.fromObject(
    { year: dep.year, month: dep.month, day: dep.day, hour: 7, minute: 0, second: 0 },
    { zone: timeZone }
  );

  const driver = await prisma.user.findUniqueOrThrow({ where: { id: intent.driverUserId } });

  const driverOrigin = await geocodeAddress(intent.originAddress);
  const driverDest = await geocodeAddress(intent.destinationAddress);

  const riderPoints: { app: AppWithRider; pickup: LatLng; drop: LatLng }[] = [];
  for (const app of sorted) {
    const pickup = await geocodeAddress(app.departureAddress);
    const drop = await geocodeAddress(app.arrivalAddress);
    riderPoints.push({ app, pickup, drop });
  }

  const intermediates: LatLng[] = [
    ...riderPoints.map((r) => r.pickup),
    ...riderPoints.map((r) => r.drop),
  ];

  const route = await computeRoute(driverOrigin, driverDest, intermediates);
  const routePolyline = route.encodedPolyline ?? null;

  let legs = route.legs;
  const expectedLegs = intermediates.length + 1;
  if (legs.length !== expectedLegs) {
    const total = legs.reduce((s, l) => s + l.durationSeconds, 0);
    if (total <= 0) {
      throw new Error("computeRoutes returned unusable legs");
    }
    const each = Math.ceil(total / expectedLegs);
    legs = Array.from({ length: expectedLegs }, () => ({
      durationSeconds: each,
      distanceMeters: 0,
    }));
  }

  const stops: {
    sequence: number;
    kind: string;
    userId: string | null;
    placeLabel: string;
    latitude: number;
    longitude: number;
    scheduledAt: Date;
  }[] = [];

  let seq = 0;
  let t = routeStart;

  stops.push({
    sequence: seq++,
    kind: "pickup",
    userId: driver.id,
    placeLabel: intent.originAddress,
    latitude: driverOrigin.latitude,
    longitude: driverOrigin.longitude,
    scheduledAt: t.toUTC().toJSDate(),
  });

  for (let i = 0; i < legs.length; i++) {
    t = t.plus({ seconds: legs[i].durationSeconds });

    if (i < K) {
      const r = riderPoints[i];
      stops.push({
        sequence: seq++,
        kind: "pickup",
        userId: r.app.riderUserId,
        placeLabel: r.app.departureAddress,
        latitude: r.pickup.latitude,
        longitude: r.pickup.longitude,
        scheduledAt: t.toUTC().toJSDate(),
      });
    } else if (i < 2 * K) {
      const j = i - K;
      const r = riderPoints[j];
      if (t.toUTC().toJSDate() > r.app.wantedArrivalAt) {
        throw new Error("route_violates_wanted_arrival");
      }
      stops.push({
        sequence: seq++,
        kind: "dropoff",
        userId: r.app.riderUserId,
        placeLabel: r.app.arrivalAddress,
        latitude: r.drop.latitude,
        longitude: r.drop.longitude,
        scheduledAt: t.toUTC().toJSDate(),
      });
    }
  }

  await prisma.$transaction(async (tx) => {
    await tx.rideStop.deleteMany({ where: { driverIntentId: intent.id } });
    for (const s of stops) {
      await tx.rideStop.create({
        data: {
          driverIntentId: intent.id,
          sequence: s.sequence,
          kind: s.kind,
          userId: s.userId,
          placeLabel: s.placeLabel,
          latitude: s.latitude,
          longitude: s.longitude,
          scheduledAt: s.scheduledAt,
        },
      });
    }
    await tx.driverIntent.update({
      where: { id: intent.id },
      data: { status: STATUS.confirmed, routePolyline },
    });
  });
}
