import type { DriverIntent, User } from "@prisma/client";
import { geocodeAddress, haversineKm, type LatLng } from "../lib/googleMaps.js";
import { config } from "../config.js";

export type IntentForMatch = DriverIntent & { driver: User; applicationCount: number };

/**
 * MVP ranking: higher score = better match.
 * Uses haversine distance from rider departure to driver origin (after geocoding both).
 * If GOOGLE_MAPS_API_KEY is missing, returns intents in arbitrary DB order with score 0.
 */
export async function rankIntentsForRider(
  intents: IntentForMatch[],
  riderDepartureAddress: string
): Promise<{ intent: IntentForMatch; score: number; driverOrigin?: LatLng; riderDep?: LatLng }[]> {
  if (!config.googleMapsApiKey || intents.length === 0) {
    return intents.map((intent) => ({
      intent,
      score: intent.passengerSeats - intent.applicationCount,
    }));
  }

  let riderDep: LatLng;
  try {
    riderDep = await geocodeAddress(riderDepartureAddress);
  } catch {
    return intents.map((intent) => ({ intent, score: 0 }));
  }

  const scored: { intent: IntentForMatch; score: number; driverOrigin?: LatLng; riderDep?: LatLng }[] =
    [];

  for (const intent of intents) {
    try {
      const driverOrigin = await geocodeAddress(intent.originAddress);
      const distKm = haversineKm(riderDep, driverOrigin);
      const proximity = 100 / (1 + distKm);
      const seatsLeft = intent.passengerSeats - intent.applicationCount;
      const score = proximity + seatsLeft * 0.5;
      scored.push({ intent, score, driverOrigin, riderDep });
    } catch {
      scored.push({ intent, score: seatsLeftScore(intent), driverOrigin: undefined, riderDep });
    }
  }

  scored.sort((a, b) => b.score - a.score);
  return scored;
}

function seatsLeftScore(intent: IntentForMatch): number {
  return intent.passengerSeats - intent.applicationCount;
}
