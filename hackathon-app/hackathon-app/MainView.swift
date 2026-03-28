import SwiftUI
import FirebaseAuth

// MARK: - Navigation destinations

enum FlowDestination: Hashable {
    case createIntent
    case myIntents
    case rideSearch
    case myRides
    case intentDetail(String)
}

// MARK: - Tab selection

enum FlowTab: Int {
    case home, drive, ride, account
}

// MARK: - Main view

struct MainView: View {
    @Environment(AppSession.self) private var session
    @State private var selectedTab: FlowTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            homeTab
            driveTab
            rideTab
            accountTab
        }
        .tint(FlowTheme.primary)
        .preferredColorScheme(.dark)
    }

    // MARK: - Home

    private var homeTab: some View {
        NavigationStack {
            HomeView()
                .navigationTitle("Zagreb Flow")
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            session.signOut()
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(FlowTheme.onSurfaceVariant)
                        }
                    }
                }
                .navigationDestination(for: FlowDestination.self) { dest in
                    destinationView(for: dest)
                }
        }
        .tag(FlowTab.home)
        .tabItem {
            Label("Home", systemImage: "house.fill")
        }
    }

    // MARK: - Drive tab

    private var driveTab: some View {
        NavigationStack {
            MyIntentsView()
                .navigationDestination(for: FlowDestination.self) { dest in
                    destinationView(for: dest)
                }
        }
        .tag(FlowTab.drive)
        .tabItem {
            Label("Drive", systemImage: "car.fill")
        }
    }

    // MARK: - Ride tab

    private var rideTab: some View {
        NavigationStack {
            MyRidesView()
                .navigationDestination(for: FlowDestination.self) { dest in
                    destinationView(for: dest)
                }
        }
        .tag(FlowTab.ride)
        .tabItem {
            Label("Ride", systemImage: "figure.walk")
        }
    }

    // MARK: - Account tab

    private var accountTab: some View {
        NavigationStack {
            AccountView()
        }
        .tag(FlowTab.account)
        .tabItem {
            Label("Account", systemImage: "person.crop.circle")
        }
    }

    // MARK: - Destination factory

    @ViewBuilder
    private func destinationView(for destination: FlowDestination) -> some View {
        switch destination {
        case .createIntent:
            CreateIntentView()
        case .myIntents:
            MyIntentsView()
        case .rideSearch:
            RideSearchView()
        case .myRides:
            MyRidesView()
        case .intentDetail(let id):
            TripDetailView(intentId: id)
        }
    }
}

// MARK: - Account view

struct AccountView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        ZStack {
            FlowTheme.surface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    infoSection
                    signOutButton
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [FlowTheme.primary, FlowTheme.secondaryContainer],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                Text(initials)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(session.firebaseUser?.displayName ?? "Commuter")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(FlowTheme.onSurface)

            if let email = session.displayEmail {
                Text(email)
                    .font(.system(size: 15))
                    .foregroundStyle(FlowTheme.onSurfaceVariant)
            }
        }
    }

    private var initials: String {
        let name = session.firebaseUser?.displayName ?? session.displayEmail ?? "?"
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var infoSection: some View {
        VStack(spacing: 2) {
            if let uid = session.userUID {
                infoRow(label: "User ID", value: String(uid.prefix(8)) + "…")
            }
            if let exp = session.tokenExpiresAt {
                infoRow(label: "Token expires", value: exp.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(FlowTheme.onSurfaceVariant)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(FlowTheme.onSurface)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(FlowTheme.surfaceContainer)
    }

    private var signOutButton: some View {
        Button("Sign Out") {
            TripStore.shared.clearAll()
            session.signOut()
        }
        .buttonStyle(FlowPrimaryButtonStyle(isDestructive: true))
        .padding(.top, 12)
    }
}

#Preview {
    MainView()
        .environment(AppSession())
}
