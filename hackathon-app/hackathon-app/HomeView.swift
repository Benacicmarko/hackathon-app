import SwiftUI
import FirebaseAuth

struct HomeView: View {
    @Environment(AppSession.self) private var session

    @State private var myIntents: [IntentSummary] = []
    @State private var myRides: [SavedApplication] = []
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                greeting

                modeCards

                if !todayIntents.isEmpty || !todayRides.isEmpty {
                    todaySection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(FlowTheme.surface)
        .task { await loadData() }
        .refreshable { await loadData() }
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(FlowTheme.onSurfaceVariant)
            Text(session.firebaseUser?.displayName ?? session.displayEmail ?? "Commuter")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(FlowTheme.onSurface)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        default: return "Good evening,"
        }
    }

    // MARK: - Mode cards

    private var modeCards: some View {
        VStack(spacing: 14) {
            NavigationLink(value: FlowDestination.createIntent) {
                modeCard(
                    icon: "car.fill",
                    title: "I'm Driving",
                    subtitle: "Offer seats on your commute",
                    gradient: [FlowTheme.primary, FlowTheme.primaryDim]
                )
            }

            NavigationLink(value: FlowDestination.rideSearch) {
                modeCard(
                    icon: "figure.walk",
                    title: "I Need a Ride",
                    subtitle: "Find a carpool to work",
                    gradient: [FlowTheme.secondary, FlowTheme.secondaryContainer]
                )
            }
        }
    }

    private func modeCard(icon: String, title: String, subtitle: String, gradient: [Color]) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(FlowTheme.onSurface)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(FlowTheme.onSurfaceVariant)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FlowTheme.outline)
        }
        .padding(18)
        .background(FlowTheme.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(gradient.first!.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Today section

    private var todayIntents: [IntentSummary] {
        let today = FlowFormatters.dateOnlyString(from: Date())
        return myIntents.filter { $0.departureDate == today && $0.intentStatus?.isActive == true }
    }

    private var todayRides: [SavedApplication] {
        let today = FlowFormatters.dateOnlyString(from: Date())
        return myRides.filter { $0.departureDate == today }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowSectionHeader(title: "Today", icon: "calendar")

            ForEach(todayIntents) { intent in
                NavigationLink(value: FlowDestination.intentDetail(intent.id)) {
                    todayIntentRow(intent)
                }
            }

            ForEach(todayRides) { ride in
                NavigationLink(value: FlowDestination.intentDetail(ride.intentId)) {
                    todayRideRow(ride)
                }
            }
        }
    }

    private func todayIntentRow(_ intent: IntentSummary) -> some View {
        FlowCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(FlowTheme.primary)
                        Text("Driving")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(FlowTheme.primary)
                    }
                    Text("\(intent.originAddress.prefix(25))…")
                        .font(.system(size: 14))
                        .foregroundStyle(FlowTheme.onSurface)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if let s = intent.intentStatus {
                        StatusBadge(status: s)
                    }
                    SeatIndicator(filled: intent.seatsFilled, total: intent.passengerSeats)
                }
            }
        }
    }

    private func todayRideRow(_ ride: SavedApplication) -> some View {
        FlowCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 12))
                            .foregroundStyle(FlowTheme.secondary)
                        Text("Riding")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(FlowTheme.secondary)
                    }
                    Text("Tap to view details")
                        .font(.system(size: 14))
                        .foregroundStyle(FlowTheme.onSurfaceVariant)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FlowTheme.outline)
            }
        }
    }

    // MARK: - Data

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        myRides = TripStore.shared.loadAll()

        do {
            let resp = try await APIClient.shared.getMyIntents()
            myIntents = resp.intents
        } catch {
            // Silently fail on home — user can pull to refresh
        }
    }
}
