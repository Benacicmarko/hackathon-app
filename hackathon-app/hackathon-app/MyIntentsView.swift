import SwiftUI

struct MyIntentsView: View {
    @State private var intents: [IntentSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            FlowTheme.surface.ignoresSafeArea()

            if isLoading && intents.isEmpty {
                ProgressView()
                    .tint(FlowTheme.primary)
            } else if intents.isEmpty {
                FlowEmptyState(
                    icon: "car",
                    title: "No rides yet",
                    subtitle: "Offer a ride and share your commute with others."
                )
            } else {
                intentsList
            }
        }
        .navigationTitle("My Rides")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: FlowDestination.createIntent) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FlowTheme.primary)
                }
            }
        }
        .task { await loadIntents() }
        .refreshable { await loadIntents() }
    }

    private var intentsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(groupedIntents.keys.sorted().reversed(), id: \.self) { date in
                    Section {
                        ForEach(groupedIntents[date] ?? []) { intent in
                            NavigationLink(value: FlowDestination.intentDetail(intent.id)) {
                                IntentRow(intent: intent) {
                                    await cancelIntent(intent)
                                }
                            }
                        }
                    } header: {
                        FlowSectionHeader(title: FlowFormatters.relativeDateLabel(date))
                            .padding(.top, date == groupedIntents.keys.sorted().reversed().first ? 0 : 8)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private var groupedIntents: [String: [IntentSummary]] {
        Dictionary(grouping: intents, by: \.departureDate)
    }

    private func loadIntents() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let resp = try await APIClient.shared.getMyIntents()
            intents = resp.intents
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancelIntent(_ intent: IntentSummary) async {
        do {
            try await APIClient.shared.deleteIntent(id: intent.id)
            await loadIntents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Intent row

struct IntentRow: View {
    let intent: IntentSummary
    var onCancel: (() async -> Void)?

    @State private var showCancelConfirm = false

    var body: some View {
        FlowCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if let status = intent.intentStatus {
                        StatusBadge(status: status)
                    }
                    Spacer()
                    SeatIndicator(filled: intent.seatsFilled, total: intent.passengerSeats)
                }

                routeInfo

                HStack {
                    Text("\(intent.seatsFilled)/\(intent.passengerSeats) riders")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FlowTheme.onSurfaceVariant)

                    Spacer()

                    if intent.intentStatus != .cancelled, let onCancel {
                        Button("Cancel") {
                            showCancelConfirm = true
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FlowTheme.error)
                        .confirmationDialog("Cancel this ride?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
                            Button("Cancel Ride", role: .destructive) {
                                Task { await onCancel() }
                            }
                        }
                    }
                }
            }
        }
    }

    private var routeInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            addressLabel(icon: "circle.fill", color: FlowTheme.primary, text: intent.originAddress)
            addressLabel(icon: "mappin.circle.fill", color: FlowTheme.error, text: intent.destinationAddress)
        }
    }

    private func addressLabel(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(FlowTheme.onSurface)
                .lineLimit(1)
        }
    }
}
