import { config } from "../config.js";

export type LatLng = { latitude: number; longitude: number };

const GEOCODE_URL = "https://maps.googleapis.com/maps/api/geocode/json";
const ROUTES_URL = "https://routes.googleapis.com/directions/v2:computeRoutes";

function hashString(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    h = (Math.imul(31, h) + s.charCodeAt(i)) | 0;
  }
  return h;
}

/** Deterministic fake coordinates (Zagreb-ish) when no Maps API key — development only. */
function mockLatLngFromString(address: string): LatLng {
  const h = hashString(address);
  const lat = 45.8 + ((h & 0xffff) / 0xffff) * 0.1;
  const lng = 15.95 + (((h >>> 16) & 0xffff) / 0xffff) * 0.15;
  return { latitude: lat, longitude: lng };
}

export async function geocodeAddress(address: string): Promise<LatLng> {
  const key = config.googleMapsApiKey;
  if (!key) {
    if (config.nodeEnv === "production") {
      throw new Error("GOOGLE_MAPS_API_KEY is not set");
    }
    return mockLatLngFromString(address);
  }
  const u = new URL(GEOCODE_URL);
  u.searchParams.set("address", address);
  u.searchParams.set("key", key);
  const res = await fetch(u.toString());
  if (!res.ok) throw new Error(`Geocoding HTTP ${res.status}`);
  const data = (await res.json()) as {
    status: string;
    results?: { geometry: { location: { lat: number; lng: number } } }[];
  };
  if (data.status !== "OK" || !data.results?.[0]) {
    throw new Error(`Geocoding failed: ${data.status}`);
  }
  const loc = data.results[0].geometry.location;
  return { latitude: loc.lat, longitude: loc.lng };
}

export type RouteLegSummary = {
  durationSeconds: number;
  distanceMeters: number;
};

export type ComputedRouteResult = {
  legs: RouteLegSummary[];
  encodedPolyline?: string;
};

function mockLegs(segmentCount: number): RouteLegSummary[] {
  return Array.from({ length: segmentCount }, (_, i) => ({
    durationSeconds: 600 + i * 120,
    distanceMeters: 5000 + i * 1000,
  }));
}

/**
 * Google Routes API v2 computeRoutes — ordered waypoints: origin -> intermediates -> destination.
 */
export async function computeRoute(
  origin: LatLng,
  destination: LatLng,
  intermediates: LatLng[],
  fieldMask = "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs.duration,routes.legs.distanceMeters"
): Promise<ComputedRouteResult> {
  const key = config.googleMapsApiKey;
  const expectedLegs = intermediates.length + 1;

  if (!key) {
    if (config.nodeEnv === "production") {
      throw new Error("GOOGLE_MAPS_API_KEY is not set");
    }
    return {
      legs: mockLegs(expectedLegs),
      encodedPolyline: undefined,
    };
  }

  const body = {
    origin: { location: { latLng: origin } },
    destination: { location: { latLng: destination } },
    intermediates: intermediates.map((ll) => ({
      location: { latLng: ll },
    })),
    travelMode: "DRIVE",
    routingPreference: "TRAFFIC_UNAWARE",
  };

  const res = await fetch(ROUTES_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": key,
      "X-Goog-FieldMask": fieldMask,
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`computeRoutes HTTP ${res.status}: ${text.slice(0, 500)}`);
  }

  const data = (await res.json()) as {
    routes?: {
      duration?: string;
      distanceMeters?: number;
      polyline?: { encodedPolyline?: string };
      legs?: { duration?: string; distanceMeters?: number }[];
    }[];
  };

  const route = data.routes?.[0];
  if (!route) {
    throw new Error("computeRoutes returned no routes");
  }

  const legs: RouteLegSummary[] = (route.legs || []).map((leg) => ({
    durationSeconds: parseDurationSeconds(leg.duration),
    distanceMeters: Number(leg.distanceMeters) || 0,
  }));

  return {
    legs,
    encodedPolyline: route.polyline?.encodedPolyline,
  };
}

function parseDurationSeconds(d?: string): number {
  if (!d) return 0;
  if (d.endsWith("s")) return Number(d.slice(0, -1)) || 0;
  return Number(d) || 0;
}

/** Haversine km — cheap proxy for match ranking without Matrix API */
export function haversineKm(a: LatLng, b: LatLng): number {
  const R = 6371;
  const dLat = deg2rad(b.latitude - a.latitude);
  const dLon = deg2rad(b.longitude - a.longitude);
  const x =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(deg2rad(a.latitude)) * Math.cos(deg2rad(b.latitude)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(x));
}

function deg2rad(d: number): number {
  return (d * Math.PI) / 180;
}
