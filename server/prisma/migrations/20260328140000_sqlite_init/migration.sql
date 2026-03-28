-- CreateTable
CREATE TABLE "users" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "firebase_uid" TEXT NOT NULL,
    "email" TEXT,
    "display_name" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- CreateTable
CREATE TABLE "driver_intents" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "driver_user_id" TEXT NOT NULL,
    "departure_date" DATETIME NOT NULL,
    "origin_address" TEXT NOT NULL,
    "destination_address" TEXT NOT NULL,
    "passenger_seats" INTEGER NOT NULL,
    "status" TEXT NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    CONSTRAINT "driver_intents_driver_user_id_fkey" FOREIGN KEY ("driver_user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "rider_applications" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "driver_intent_id" TEXT NOT NULL,
    "rider_user_id" TEXT NOT NULL,
    "departure_address" TEXT NOT NULL,
    "arrival_address" TEXT NOT NULL,
    "wanted_arrival_at" DATETIME NOT NULL,
    "client_time_zone" TEXT NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "rider_applications_driver_intent_id_fkey" FOREIGN KEY ("driver_intent_id") REFERENCES "driver_intents" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "rider_applications_rider_user_id_fkey" FOREIGN KEY ("rider_user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "ride_stops" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "driver_intent_id" TEXT NOT NULL,
    "sequence" INTEGER NOT NULL,
    "kind" TEXT NOT NULL,
    "user_id" TEXT,
    "place_label" TEXT NOT NULL,
    "latitude" REAL NOT NULL,
    "longitude" REAL NOT NULL,
    "scheduled_at" DATETIME NOT NULL,
    CONSTRAINT "ride_stops_driver_intent_id_fkey" FOREIGN KEY ("driver_intent_id") REFERENCES "driver_intents" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "ride_stops_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

-- CreateIndex
CREATE UNIQUE INDEX "users_firebase_uid_key" ON "users"("firebase_uid");

-- CreateIndex
CREATE INDEX "driver_intents_driver_user_id_departure_date_idx" ON "driver_intents"("driver_user_id", "departure_date");

-- CreateIndex
CREATE INDEX "rider_applications_driver_intent_id_idx" ON "rider_applications"("driver_intent_id");

-- CreateIndex
CREATE INDEX "rider_applications_rider_user_id_idx" ON "rider_applications"("rider_user_id");

-- CreateIndex
CREATE UNIQUE INDEX "rider_applications_driver_intent_id_rider_user_id_key" ON "rider_applications"("driver_intent_id", "rider_user_id");

-- CreateIndex
CREATE INDEX "ride_stops_driver_intent_id_idx" ON "ride_stops"("driver_intent_id");
