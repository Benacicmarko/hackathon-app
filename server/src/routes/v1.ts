import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { prisma } from "../lib/prisma.js";
import { authenticate } from "../plugins/auth.js";
import {
  isApplicationCutoffPassed,
  canCancelApplication,
  parseIsoDateOnly,
  parseDepartureDateInput,
  localDayUtcRange,
} from "../lib/timezone.js";
import { buildAndPersistRoute, STATUS } from "../services/routingService.js";

const createIntentSchema = z.object({
  departureDate: z.string(),
  originAddress: z.string().min(1),
  destinationAddress: z.string().min(1),
  passengerSeats: z.number().int().min(1).max(8),
  clientTimeZone: z.string().min(1),
});

const matchesSchema = z.object({
  departureDate: z.string(),
  riderDepartureAddress: z.string().min(1),
  riderArrivalAddress: z.string().min(1),
  wantedArrivalAt: z.string(),
  clientTimeZone: z.string().min(1),
});

const applySchema = z.object({
  riderDepartureAddress: z.string().min(1),
  riderArrivalAddress: z.string().min(1),
  wantedArrivalAt: z.string(),
  clientTimeZone: z.string().min(1),
});

const cancelAppSchema = z.object({
  clientTimeZone: z.string().min(1),
});

function parseInstant(s: string): Date {
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) throw new Error("invalid datetime");
  return d;
}

export async function registerV1Routes(app: FastifyInstance): Promise<void> {
  app.get("/me", { preHandler: authenticate }, async (request) => {
    const u = request.user!;
    return {
      id: u.id,
      displayName: u.displayName,
      email: u.email,
    };
  });

  app.post("/driver-intents", { preHandler: authenticate }, async (request, reply) => {
    const parsed = createIntentSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: "validation_error", details: parsed.error.flatten() });
    }
    const b = parsed.data;
    const userId = request.user!.id;
    let departureDate: Date;
    try {
      departureDate = parseDepartureDateInput(b.departureDate);
    } catch {
      return reply.code(400).send({ error: "invalid_departure_date" });
    }

    const intent = await prisma.driverIntent.create({
      data: {
        driverUserId: userId,
        departureDate,
        originAddress: b.originAddress,
        destinationAddress: b.destinationAddress,
        passengerSeats: b.passengerSeats,
        status: STATUS.collecting,
      },
    });

    return reply.code(201).send({
      id: intent.id,
      status: intent.status,
      departureDate: intent.departureDate.toISOString(),
      passengerSeats: intent.passengerSeats,
    });
  });

  app.get("/driver-intents/mine", { preHandler: authenticate }, async (request) => {
    const userId = request.user!.id;
    const q = request.query as { from?: string; to?: string };
    const where: {
      driverUserId: string;
      departureDate?: { gte?: Date; lte?: Date };
    } = { driverUserId: userId };
    const dateFilter: { gte?: Date; lte?: Date } = {};
    if (q.from) {
      try {
        dateFilter.gte = parseIsoDateOnly(q.from);
      } catch {
        /* ignore */
      }
    }
    if (q.to) {
      try {
        dateFilter.lte = parseIsoDateOnly(q.to);
      } catch {
        /* ignore */
      }
    }
    if (dateFilter.gte || dateFilter.lte) {
      where.departureDate = dateFilter;
    }

    const list = await prisma.driverIntent.findMany({
      where,
      orderBy: { departureDate: "asc" },
      include: {
        _count: { select: { applications: true } },
      },
    });

    return {
      intents: list.map((i) => ({
        id: i.id,
        departureDate: i.departureDate.toISOString().slice(0, 10),
        originAddress: i.originAddress,
        destinationAddress: i.destinationAddress,
        passengerSeats: i.passengerSeats,
        status: i.status,
        seatsFilled: i._count.applications,
        seatsRemaining: i.passengerSeats - i._count.applications,
      })),
    };
  });

  app.delete("/driver-intents/:id", { preHandler: authenticate }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = request.user!.id;
    const intent = await prisma.driverIntent.findUnique({ where: { id } });
    if (!intent) return reply.code(404).send({ error: "not_found" });
    if (intent.driverUserId !== userId) return reply.code(403).send({ error: "forbidden" });
    if (intent.status === STATUS.cancelled) return reply.code(204).send();

    await prisma.driverIntent.update({
      where: { id },
      data: { status: STATUS.cancelled },
    });
    await prisma.riderApplication.deleteMany({ where: { driverIntentId: id } });
    await prisma.rideStop.deleteMany({ where: { driverIntentId: id } });
    return reply.code(204).send();
  });

  app.post("/driver-intents/matches", { preHandler: authenticate }, async (request, reply) => {
    const parsed = matchesSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: "validation_error", details: parsed.error.flatten() });
    }
    const b = parsed.data;
    let departureDate: Date;
    try {
      departureDate = parseIsoDateOnly(b.departureDate);
    } catch {
      return reply.code(400).send({ error: "invalid_departure_date" });
    }

    let wantedArrivalAt: Date;
    try {
      wantedArrivalAt = parseInstant(b.wantedArrivalAt);
    } catch {
      return reply.code(400).send({ error: "invalid_wanted_arrival" });
    }
    const { startUtc, endUtc } = localDayUtcRange(departureDate, b.clientTimeZone);

    const userId = request.user!.id;
    const open = await prisma.driverIntent.findMany({
      where: {
        departureDate: {
          gte: startUtc,
          lt: endUtc,
        },
        status: STATUS.collecting,
        driverUserId: { not: userId },
      },
      include: {
        driver: true,
        applications: true,
      },
    });

    const thirtyMinutesMs = 30 * 60 * 1000;
    const candidates = open
      .map((i) => ({
        ...i,
        applicationCount: i.applications.length,
      }))
      .filter((i) => i.applicationCount < i.passengerSeats)
      .filter(
        (i) => Math.abs(i.departureDate.getTime() - wantedArrivalAt.getTime()) <= thirtyMinutesMs
      );

    const ranked = candidates
      .map((intent) => {
        const timeDeltaMs = Math.abs(intent.departureDate.getTime() - wantedArrivalAt.getTime());
        const score = Math.max(0, 1 - timeDeltaMs / thirtyMinutesMs);
        return { intent, score, timeDeltaMs };
      })
      .sort((a, b) => {
        if (a.timeDeltaMs !== b.timeDeltaMs) return a.timeDeltaMs - b.timeDeltaMs;
        const seatsA = a.intent.passengerSeats - a.intent.applicationCount;
        const seatsB = b.intent.passengerSeats - b.intent.applicationCount;
        return seatsB - seatsA;
      });

    return {
      matches: ranked.map((r) => ({
        intentId: r.intent.id,
        score: Math.round(r.score * 1000) / 1000,
        driverDisplayName: r.intent.driver.displayName,
        seatsRemaining: r.intent.passengerSeats - r.intent.applicationCount,
        departureDate: r.intent.departureDate.toISOString(),
        originAddress: r.intent.originAddress,
        destinationAddress: r.intent.destinationAddress,
      })),
    };
  });

  app.post(
    "/driver-intents/:intentId/applications",
    { preHandler: authenticate },
    async (request, reply) => {
      const { intentId } = request.params as { intentId: string };
      const parsed = applySchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: "validation_error", details: parsed.error.flatten() });
      }
      const b = parsed.data;
      const riderUserId = request.user!.id;

      let wantedArrivalAt: Date;
      try {
        wantedArrivalAt = parseInstant(b.wantedArrivalAt);
      } catch {
        return reply.code(400).send({ error: "invalid_wanted_arrival" });
      }

      const intent = await prisma.driverIntent.findUnique({
        where: { id: intentId },
        include: { applications: true },
      });

      if (!intent) return reply.code(404).send({ error: "intent_not_found" });
      if (intent.status === STATUS.cancelled) {
        return reply.code(409).send({ error: "intent_cancelled" });
      }
      if (intent.status === STATUS.confirmed || intent.status === STATUS.routing) {
        return reply.code(409).send({ error: "intent_not_accepting_applications" });
      }

      if (isApplicationCutoffPassed(new Date(), intent.departureDate, b.clientTimeZone)) {
        return reply.code(409).send({ error: "application_cutoff_passed" });
      }

      if (intent.driverUserId === riderUserId) {
        return reply.code(409).send({ error: "cannot_apply_to_own_intent" });
      }

      const existing = intent.applications.find((a) => a.riderUserId === riderUserId);
      if (existing) {
        return reply.code(409).send({ error: "already_applied" });
      }

      const count = intent.applications.length;
      if (count >= intent.passengerSeats) {
        return reply.code(409).send({ error: "intent_full" });
      }

      try {
        const result = await prisma.$transaction(async (tx) => {
          const appRow = await tx.riderApplication.create({
            data: {
              driverIntentId: intentId,
              riderUserId,
              departureAddress: b.riderDepartureAddress,
              arrivalAddress: b.riderArrivalAddress,
              wantedArrivalAt,
              clientTimeZone: b.clientTimeZone,
            },
          });

          const fresh = await tx.driverIntent.findUniqueOrThrow({
            where: { id: intentId },
            include: { applications: { include: { rider: true } } },
          });

          const newCount = fresh.applications.length;

          if (newCount === fresh.passengerSeats) {
            await tx.driverIntent.update({
              where: { id: intentId },
              data: { status: STATUS.routing },
            });
            return {
              appRow,
              filled: true as const,
              intentWithRiders: fresh,
              routingStatus: "pending" as const,
            };
          }

          return {
            appRow,
            filled: false as const,
            intentWithRiders: null,
            routingStatus: undefined as undefined,
          };
        });

        if (result.filled && result.intentWithRiders) {
          try {
            await buildAndPersistRoute(
              result.intentWithRiders,
              result.intentWithRiders.applications
            );
          } catch (e) {
            const msg = e instanceof Error ? e.message : "routing_failed";
            await prisma.riderApplication.delete({ where: { id: result.appRow.id } });
            await prisma.driverIntent.update({
              where: { id: intentId },
              data: { status: STATUS.collecting },
            });
            return reply.code(409).send({ error: "routing_failed", message: msg });
          }
        }

        const after = await prisma.driverIntent.findUniqueOrThrow({
          where: { id: intentId },
          include: { _count: { select: { applications: true } } },
        });

        return reply.code(201).send({
          id: result.appRow.id,
          intentId,
          seatsFilled: after._count.applications,
          seatsTotal: after.passengerSeats,
          status: after.status,
          routingStatus: result.routingStatus,
        });
      } catch (e) {
        const code = (e as { code?: string }).code;
        if (code === "P2002") {
          return reply.code(409).send({ error: "already_applied" });
        }
        throw e;
      }
    }
  );

  app.delete("/applications/:id", { preHandler: authenticate }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const parsed = cancelAppSchema.safeParse(request.body ?? {});
    if (!parsed.success) {
      return reply.code(400).send({ error: "validation_error", details: parsed.error.flatten() });
    }
    const { clientTimeZone } = parsed.data;
    const riderUserId = request.user!.id;

    const appRow = await prisma.riderApplication.findUnique({
      where: { id },
      include: { intent: true },
    });

    if (!appRow) return reply.code(404).send({ error: "not_found" });
    if (appRow.riderUserId !== riderUserId) return reply.code(403).send({ error: "forbidden" });

    if (!canCancelApplication(new Date(), appRow.intent.departureDate, clientTimeZone)) {
      return reply.code(409).send({ error: "cancel_not_allowed_day_before_rule" });
    }

    const wasConfirmed = appRow.intent.status === STATUS.confirmed;

    await prisma.riderApplication.delete({ where: { id } });

    if (wasConfirmed) {
      await prisma.rideStop.deleteMany({ where: { driverIntentId: appRow.driverIntentId } });
      await prisma.driverIntent.update({
        where: { id: appRow.driverIntentId },
        data: { status: STATUS.collecting },
      });
    }

    return reply.code(204).send();
  });

  app.get("/driver-intents/:id/detail", { preHandler: authenticate }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = request.user!.id;

    const intent = await prisma.driverIntent.findUnique({
      where: { id },
      include: {
        applications: { include: { rider: true } },
        stops: { orderBy: { sequence: "asc" } },
        driver: true,
      },
    });

    if (!intent) return reply.code(404).send({ error: "not_found" });

    const isDriver = intent.driverUserId === userId;
    const isRider = intent.applications.some((a) => a.riderUserId === userId);
    if (!isDriver && !isRider) {
      return reply.code(403).send({ error: "forbidden" });
    }

    return {
      id: intent.id,
      status: intent.status,
      departureDate: intent.departureDate.toISOString().slice(0, 10),
      originAddress: intent.originAddress,
      destinationAddress: intent.destinationAddress,
      passengerSeats: intent.passengerSeats,
      driver: {
        id: intent.driver.id,
        displayName: intent.driver.displayName,
      },
      applications: intent.applications.map((a) => ({
        id: a.id,
        riderId: a.riderUserId,
        riderDisplayName: a.rider.displayName,
        departureAddress: a.departureAddress,
        arrivalAddress: a.arrivalAddress,
        wantedArrivalAt: a.wantedArrivalAt.toISOString(),
        createdAt: a.createdAt.toISOString(),
      })),
      stops: intent.stops.map((s) => ({
        sequence: s.sequence,
        kind: s.kind,
        userId: s.userId,
        placeLabel: s.placeLabel,
        latitude: s.latitude,
        longitude: s.longitude,
        scheduledAt: s.scheduledAt.toISOString(),
      })),
    };
  });
}
