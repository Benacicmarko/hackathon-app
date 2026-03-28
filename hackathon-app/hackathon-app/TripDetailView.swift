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
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Content

    private func detailContent(_ d: IntentDetailResponse) -> some View {
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
        let coords = d.stops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let region = regionForCoordinates(coords)

        return VStack(alignment: .leading, spacing: 8) {
            FlowSectionHeader(title: "Route Map", icon: "map")
            Map(initialPosition: .region(region)) {
                ForEach(d.stops) { stop in
                    Annotation(
                        stop.placeLabel,
                        coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
                    ) {
                        stopMarker(stop)
                    }
                }
                MapPolyline(coordinates: coords)
                    .stroke(FlowTheme.primary, lineWidth: 3)
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func stopMarker(_ stop: StopInfo) -> some View {
        ZStack {
            Circle()
                .fill(stop.isPickup ? FlowTheme.primary : FlowTheme.error)
                .frame(width: 28, height: 28)
            Image(systemName: stop.isPickup ? "arrow.up" : "arrow.down")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
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

            if d.intentStatus == .fullRouting {
                Button("Refresh Status") { Task { await load() } }
                    .buttonStyle(FlowSecondaryButtonStyle())
            }

            if let app = myApplication, d.intentStatus != .cancelled {
                Button("Cancel My Application") { showCancelConfirm = true }
                    .buttonStyle(FlowPrimaryButtonStyle(isDestructive: true))
                    .disabled(isCancelling)
                    .confirmationDialog("Cancel your ride application?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
                        Button("Cancel Application", role: .destructive) {
                            Task { await cancelMyApplication(app.id) }
                        }
                    }
            }

            if isDriver && d.intentStatus != .cancelled {
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
