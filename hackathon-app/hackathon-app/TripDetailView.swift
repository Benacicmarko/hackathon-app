import CoreLocation
import MapKit
import SwiftUI

struct TripDetailView: View {
    let intentId: String

    @Environment(AppSession.self) private var session
    @State private var detail: IntentDetailResponse?
    @State private var meId: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCancelConfirm = false
    @State private var isCancelling = false
    @State private var isStarting = false
    @State private var isFinishing = false
    @State private var showFinishConfirm = false
    @State private var pollingTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            FlowTheme.surface.ignoresSafeArea()

            if isLoading && detail == nil {
                ProgressView().tint(FlowTheme.primary)
            } else if let detail {
                detailContent(detail)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    FlowEmptyState(icon: "exclamationmark.triangle", title: "Error", subtitle: errorMessage)
                    Button("Retry") { Task { await load() } }
                        .buttonStyle(FlowSecondaryButtonStyle())
                        .padding(.horizontal, 40)
                }
            }
        }
        .navigationTitle("Trip Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load(); startPollingIfNeeded() }
        .refreshable { await load() }
        .onDisappear { pollingTask?.cancel() }
    }

    // MARK: - Content

    private var isRider: Bool {
        guard let meId, let detail else { return false }
        return detail.driver.id != meId
    }

    private func detailContent(_ d: IntentDetailResponse) -> some View {
        Group {
            if d.intentStatus == .completed {
                rideFinishedView(d)
            } else if d.intentStatus == .inProgress && isRider {
                rideInProgressView(d)
            } else {
                normalDetailContent(d)
            }
        }
    }

    private func normalDetailContent(_ d: IntentDetailResponse) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                statusHeader(d)

                if !d.stops.isEmpty {
                    mapSection(d)
                }

                routeCard(d)
                participantsSection(d)

                if !d.stops.isEmpty {
                    stopsSection(d)
                }

                actionSection(d)

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }

    // MARK: - Status header

    private func statusHeader(_ d: IntentDetailResponse) -> some View {
        VStack(spacing: 8) {
            if let status = d.intentStatus {
                StatusBadge(status: status)
            }
            Text(FlowFormatters.relativeDateLabel(d.departureDate))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(FlowTheme.onSurface)

            if d.intentStatus == .fullRouting {
                HStack(spacing: 8) {
                    ProgressView().tint(FlowTheme.warning)
                    Text("Computing the best route…")
                        .font(.system(size: 14))
                        .foregroundStyle(FlowTheme.warning)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Map

    private func mapSection(_ d: IntentDetailResponse) -> some View {
        let stopCoords = d.stops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let routeCoords: [CLLocationCoordinate2D] = {
            if let polyline = d.routePolyline {
                let decoded = PolylineDecoder.decode(polyline)
                if !decoded.isEmpty { return decoded }
            }
            return stopCoords
        }()
        let allCoords = routeCoords + stopCoords
        let region = regionForCoordinates(allCoords)

        return VStack(alignment: .leading, spacing: 8) {
            FlowSectionHeader(title: "Route Map", icon: "map")
            Map(initialPosition: .region(region)) {
                MapPolyline(coordinates: routeCoords)
                    .stroke(
                        FlowTheme.primary.opacity(0.8),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                    )

                ForEach(d.stops) { stop in
                    Annotation(
                        stop.placeLabel,
                        coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
                    ) {
                        stopMarker(stop, detail: d)
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            mapLegend()
        }
    }

    private func stopMarker(_ stop: StopInfo, detail d: IntentDetailResponse) -> some View {
        let isDriverStop = stop.userId == d.driver.id
        let markerColor: Color = {
            if isDriverStop { return FlowTheme.warning }
            return stop.isPickup ? FlowTheme.primary : FlowTheme.error
        }()
        let iconName: String = {
            if isDriverStop { return "car.fill" }
            return stop.isPickup ? "person.fill.badge.plus" : "person.fill.checkmark"
        }()

        return VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(markerColor)
                    .frame(width: 34, height: 34)
                    .shadow(color: markerColor.opacity(0.4), radius: 4, y: 2)
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(riderName(for: stop, in: d))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(FlowTheme.onSurface)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(FlowTheme.surfaceContainerHi.opacity(0.9))
                .clipShape(Capsule())
        }
    }

    private func riderName(for stop: StopInfo, in d: IntentDetailResponse) -> String {
        if stop.userId == d.driver.id { return "You (Driver)" }
        if let app = d.applications.first(where: { $0.riderId == stop.userId }) {
            let name = app.riderDisplayName ?? "Rider"
            return stop.isPickup ? "\(name) pickup" : "\(name) dropoff"
        }
        return stop.isPickup ? "Pickup" : "Dropoff"
    }

    private func mapLegend() -> some View {
        HStack(spacing: 16) {
            legendItem(color: FlowTheme.warning, icon: "car.fill", label: "Driver")
            legendItem(color: FlowTheme.primary, icon: "person.fill.badge.plus", label: "Pickup")
            legendItem(color: FlowTheme.error, icon: "person.fill.checkmark", label: "Dropoff")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func legendItem(color: Color, icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            ZStack {
                Circle().fill(color).frame(width: 20, height: 20)
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(FlowTheme.onSurfaceVariant)
        }
    }

    // MARK: - Route card

    private func routeCard(_ d: IntentDetailResponse) -> some View {
        FlowCard {
            VStack(alignment: .leading, spacing: 10) {
                FlowSectionHeader(title: "Route", icon: "arrow.triangle.swap")
                addressLine(icon: "circle.fill", color: FlowTheme.primary, text: d.originAddress)
                addressLine(icon: "mappin.circle.fill", color: FlowTheme.error, text: d.destinationAddress)
                HStack {
                    Label("\(d.passengerSeats) seat\(d.passengerSeats == 1 ? "" : "s")", systemImage: "person.2")
                        .font(.system(size: 13))
                        .foregroundStyle(FlowTheme.onSurfaceVariant)
                    Spacer()
                    SeatIndicator(filled: d.applications.count, total: d.passengerSeats)
                }
            }
        }
    }

    // MARK: - Participants

    private func participantsSection(_ d: IntentDetailResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowSectionHeader(title: "Participants", icon: "person.3")

            FlowCard {
                HStack(spacing: 10) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(FlowTheme.primary)
                        .frame(width: 32, height: 32)
                        .background(FlowTheme.primary.opacity(0.12))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(d.driver.displayName ?? "Driver")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FlowTheme.onSurface)
                        Text("Driver")
                            .font(.system(size: 12))
                            .foregroundStyle(FlowTheme.onSurfaceVariant)
                    }
                    Spacer()
                }
            }

            ForEach(d.applications) { app in
                FlowCard {
                    HStack(spacing: 10) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 16))
                            .foregroundStyle(FlowTheme.secondary)
                            .frame(width: 32, height: 32)
                            .background(FlowTheme.secondary.opacity(0.12))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 1) {
                            Text(app.riderDisplayName ?? "Rider")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(FlowTheme.onSurface)
                            Text("Arrive by \(FlowFormatters.displayTime(app.wantedArrivalAt))")
                                .font(.system(size: 12))
                                .foregroundStyle(FlowTheme.onSurfaceVariant)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Stops timeline

    private func stopsSection(_ d: IntentDetailResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowSectionHeader(title: "Schedule", icon: "clock")

            ForEach(d.stops) { stop in
                HStack(spacing: 12) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(stop.isPickup ? FlowTheme.primary : FlowTheme.error)
                            .frame(width: 10, height: 10)
                        if stop.sequence < d.stops.count - 1 {
                            Rectangle()
                                .fill(FlowTheme.outline.opacity(0.4))
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 10)

                    FlowCard {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(stop.isPickup ? "Pickup" : "Dropoff")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(stop.isPickup ? FlowTheme.primary : FlowTheme.error)
                                    .textCase(.uppercase)
                                Spacer()
                                Text(FlowFormatters.displayTime(stop.scheduledAt))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(FlowTheme.onSurface)
                            }
                            Text(stop.placeLabel)
                                .font(.system(size: 14))
                                .foregroundStyle(FlowTheme.onSurfaceVariant)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func actionSection(_ d: IntentDetailResponse) -> some View {
        Group {
            let isDriver = meId != nil && d.driver.id == meId
            let myApplication = findMyApplication(d)

            if isDriver && d.intentStatus == .confirmed && !d.stops.isEmpty {
                Button {
                    Task { await startRide(d) }
                } label: {
                    HStack(spacing: 10) {
                        if isStarting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "location.fill")
                                .font(.system(size: 18))
                        }
                        Text("Start Ride")
                            .font(.system(size: 17, weight: .bold))
                    }
                }
                .buttonStyle(FlowPrimaryButtonStyle())
                .disabled(isStarting)
            }

            if isDriver && d.intentStatus == .inProgress {
                Button {
                    showFinishConfirm = true
                } label: {
                    HStack(spacing: 10) {
                        if isFinishing {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 18))
                        }
                        Text("Finish Ride")
                            .font(.system(size: 17, weight: .bold))
                    }
                }
                .buttonStyle(FlowPrimaryButtonStyle())
                .disabled(isFinishing)
                .confirmationDialog("Mark this ride as finished?", isPresented: $showFinishConfirm, titleVisibility: .visible) {
                    Button("Finish Ride") {
                        Task { await finishRide(d) }
                    }
                }
            }

            if d.intentStatus == .fullRouting {
                Button("Refresh Status") { Task { await load() } }
                    .buttonStyle(FlowSecondaryButtonStyle())
            }

            if let app = myApplication, d.intentStatus != .cancelled && d.intentStatus != .completed {
                Button("Cancel My Application") { showCancelConfirm = true }
                    .buttonStyle(FlowPrimaryButtonStyle(isDestructive: true))
                    .disabled(isCancelling)
                    .confirmationDialog("Cancel your ride application?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
                        Button("Cancel Application", role: .destructive) {
                            Task { await cancelMyApplication(app.id) }
                        }
                    }
            }

            if isDriver && d.intentStatus != .cancelled && d.intentStatus != .completed && d.intentStatus != .inProgress {
                Button("Cancel Ride") { showCancelConfirm = true }
                    .buttonStyle(FlowPrimaryButtonStyle(isDestructive: true))
                    .disabled(isCancelling)
                    .confirmationDialog("Cancel this ride? All riders will lose their spot.", isPresented: $showCancelConfirm, titleVisibility: .visible) {
                        Button("Cancel Ride", role: .destructive) {
                            Task { await cancelRide(d.id) }
                        }
                    }
            }
        }
    }

    // MARK: - Ride In Progress (rider view)

    private func rideInProgressView(_ d: IntentDetailResponse) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(FlowTheme.primary.opacity(0.15))
                        .frame(width: 120, height: 120)
                    Circle()
                        .fill(FlowTheme.primary.opacity(0.25))
                        .frame(width: 90, height: 90)
                    Image(systemName: "car.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(FlowTheme.primary)
                        .symbolEffect(.pulse, options: .repeating)
                }

                VStack(spacing: 8) {
                    Text("Your ride has started!")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(FlowTheme.onSurface)
                        .multilineTextAlignment(.center)

                    Text("\(d.driver.displayName ?? "Your driver") is on the way")
                        .font(.system(size: 17))
                        .foregroundStyle(FlowTheme.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                }

                if let myStop = myPickupStop(d) {
                    FlowCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(FlowTheme.primary)
                                Text("Your pickup")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(FlowTheme.onSurfaceVariant)
                            }
                            Text(myStop.placeLabel)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(FlowTheme.onSurface)
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                    .foregroundStyle(FlowTheme.onSurfaceVariant)
                                Text("ETA: \(FlowFormatters.displayTime(myStop.scheduledAt))")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(FlowTheme.primary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                Text("Be ready at your pickup point")
                    .font(.system(size: 14))
                    .foregroundStyle(FlowTheme.onSurfaceVariant)

                if !d.stops.isEmpty {
                    mapSection(d)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 32)
        }
    }

    private func myPickupStop(_ d: IntentDetailResponse) -> StopInfo? {
        guard let meId else { return nil }
        return d.stops.first { $0.userId == meId && $0.isPickup }
    }

    // MARK: - Ride Finished

    private func rideFinishedView(_ d: IntentDetailResponse) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(FlowTheme.primary.opacity(0.15))
                        .frame(width: 120, height: 120)
                    Circle()
                        .fill(FlowTheme.primary.opacity(0.25))
                        .frame(width: 90, height: 90)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(FlowTheme.primary)
                }

                VStack(spacing: 8) {
                    Text("Ride Complete!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(FlowTheme.onSurface)
                        .multilineTextAlignment(.center)

                    Text(isRider
                         ? "Thanks for riding with \(d.driver.displayName ?? "your driver")!"
                         : "Great job! All riders have been dropped off.")
                        .font(.system(size: 17))
                        .foregroundStyle(FlowTheme.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                FlowCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.swap")
                                .foregroundStyle(FlowTheme.primary)
                            Text("Route Summary")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(FlowTheme.onSurfaceVariant)
                        }
                        addressLine(icon: "circle.fill", color: FlowTheme.primary, text: d.originAddress)
                        addressLine(icon: "mappin.circle.fill", color: FlowTheme.error, text: d.destinationAddress)
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(FlowTheme.onSurfaceVariant)
                            Text("\(d.applications.count) rider\(d.applications.count == 1 ? "" : "s")")
                                .font(.system(size: 13))
                                .foregroundStyle(FlowTheme.onSurfaceVariant)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()

            Button {
                if isRider {
                    if let app = findMyApplication(d) {
                        TripStore.shared.remove(applicationId: app.id)
                    }
                }
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FlowPrimaryButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Google Maps Navigation

    private func openGoogleMapsNavigation(_ d: IntentDetailResponse) {
        let sortedStops = d.stops.sorted { $0.sequence < $1.sequence }

        var pathSegments: [String] = sortedStops.map { "\($0.latitude),\($0.longitude)" }
        let destination = d.destinationAddress
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? d.destinationAddress
        pathSegments.append(destination)

        let urlString = "https://www.google.com/maps/dir/" + pathSegments.joined(separator: "/")
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Helpers

    private func findMyApplication(_ d: IntentDetailResponse) -> ApplicationInfo? {
        let saved = TripStore.shared.loadAll()
        let savedAppIds = Set(saved.map(\.applicationId))
        return d.applications.first { savedAppIds.contains($0.id) }
    }

    private func addressLine(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(FlowTheme.onSurface)
                .lineLimit(2)
        }
    }

    private func regionForCoordinates(_ coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coords.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 45.8, longitude: 15.97),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((lats.max()! - lats.min()!) * 1.5, 0.01),
            longitudeDelta: max((lngs.max()! - lngs.min()!) * 1.5, 0.01)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Network

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let detailFetch = APIClient.shared.getIntentDetail(id: intentId)
            async let meFetch = APIClient.shared.getMe()
            let (d, me) = try await (detailFetch, meFetch)
            detail = d
            meId = me.id
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startRide(_ d: IntentDetailResponse) async {
        isStarting = true
        defer { isStarting = false }

        do {
            try await APIClient.shared.startRide(intentId: d.id)
            await load()
            openGoogleMapsNavigation(d)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finishRide(_ d: IntentDetailResponse) async {
        isFinishing = true
        defer { isFinishing = false }

        do {
            try await APIClient.shared.finishRide(intentId: d.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startPollingIfNeeded() {
        let status = detail?.intentStatus
        guard isRider, status == .confirmed || status == .inProgress else { return }
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await load()
                let current = detail?.intentStatus
                if current != .confirmed && current != .inProgress { break }
            }
        }
    }

    private func cancelMyApplication(_ appId: String) async {
        isCancelling = true
        defer { isCancelling = false }

        do {
            try await APIClient.shared.cancelApplication(id: appId, timeZone: TimeZone.current.identifier)
            TripStore.shared.remove(applicationId: appId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancelRide(_ id: String) async {
        isCancelling = true
        defer { isCancelling = false }

        do {
            try await APIClient.shared.deleteIntent(id: id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
