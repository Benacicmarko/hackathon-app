import SwiftUI

struct MyRidesView: View {
    @State private var savedApps: [SavedApplication] = []
    @State private var details: [String: IntentDetailResponse] = [:]
    @State private var isLoading = false

    var body: some View {
        ZStack {
            FlowTheme.surface.ignoresSafeArea()

            if isLoading && details.isEmpty && !savedApps.isEmpty {
                ProgressView().tint(FlowTheme.primary)
            } else if savedApps.isEmpty {
                FlowEmptyState(
                    icon: "figure.walk",
                    title: "No rides yet",
                    subtitle: "Search for a ride and apply to a driver's commute."
                )
            } else {
                ridesList
            }
        }
        .navigationTitle("My Rides")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: FlowDestination.rideSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FlowTheme.primary)
                }
            }
        }
        .task { await loadAll() }
        .refreshable { await loadAll() }
    }

    private var ridesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(savedApps) { saved in
                    NavigationLink(value: FlowDestination.intentDetail(saved.intentId)) {
                        rideRow(saved)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private func rideRow(_ saved: SavedApplication) -> some View {
        FlowCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(FlowFormatters.relativeDateLabel(saved.departureDate))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(FlowTheme.onSurface)
                    Spacer()
                    if let d = details[saved.intentId], let s = d.intentStatus {
                        StatusBadge(status: s)
                    } else {
                        ProgressView()
                            .tint(FlowTheme.onSurfaceVariant)
                            .scaleEffect(0.7)
                    }
                }

                if let d = details[saved.intentId] {
                    VStack(alignment: .leading, spacing: 4) {
                        addressLine(icon: "circle.fill", color: FlowTheme.secondary, text: d.originAddress)
                        addressLine(icon: "mappin.circle.fill", color: FlowTheme.error, text: d.destinationAddress)
                    }

                    HStack {
                        Label(d.driver.displayName ?? "Driver", systemImage: "car.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(FlowTheme.onSurfaceVariant)
                        Spacer()
                        SeatIndicator(filled: d.applications.count, total: d.passengerSeats)
                    }
                }
            }
        }
    }

    private func addressLine(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(FlowTheme.onSurfaceVariant)
                .lineLimit(1)
        }
    }

    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }

        savedApps = TripStore.shared.loadAll().sorted { $0.savedAt > $1.savedAt }

        for saved in savedApps {
            if let detail = try? await APIClient.shared.getIntentDetail(id: saved.intentId) {
                details[saved.intentId] = detail
            }
        }
    }
}
