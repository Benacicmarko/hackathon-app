import SwiftUI

struct RideSearchView: View {
    @State private var departureDate = RideSearchView.defaultSearchDate()
    @State private var departureAddress = ""
    @State private var arrivalAddress = ""
    @State private var wantedArrivalTime = defaultArrivalTime()
    @State private var matches: [MatchResult]?
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                searchForm

                if let errorMessage {
                    errorBanner(errorMessage)
                }

                searchButton

                if let matches {
                    matchResultsSection(matches)
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(FlowTheme.surface)
        .navigationTitle("Find a Ride")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(FlowTheme.secondary)
            Text("Where are you going?")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(FlowTheme.onSurface)
            Text("Find a driver heading your way.")
                .font(.system(size: 15))
                .foregroundStyle(FlowTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Form

    private var searchForm: some View {
        VStack(spacing: 16) {
            dateRow

            VStack(alignment: .leading, spacing: 8) {
                FlowSectionHeader(title: "Your Trip", icon: "map")
                VStack(spacing: 2) {
                    AddressSearchField(
                        icon: "circle.fill",
                        iconColor: FlowTheme.secondary,
                        placeholder: "Your pickup address",
                        address: $departureAddress
                    )
                    dotConnector
                    AddressSearchField(
                        icon: "mappin.circle.fill",
                        iconColor: FlowTheme.error,
                        placeholder: "Your destination",
                        address: $arrivalAddress
                    )
                }
            }
            .zIndex(1)

            arrivalTimeRow
        }
    }

    private var dateRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowSectionHeader(title: "Date", icon: "calendar")
            DatePicker(
                "Departure date",
                selection: $departureDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .tint(FlowTheme.primary)
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(FlowTheme.surfaceContainerHi)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .foregroundStyle(FlowTheme.onSurface)
        }
    }

    private var arrivalTimeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowSectionHeader(title: "Arrive By", icon: "clock")
            DatePicker(
                "Wanted arrival time",
                selection: $wantedArrivalTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.compact)
            .tint(FlowTheme.primary)
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(FlowTheme.surfaceContainerHi)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .foregroundStyle(FlowTheme.onSurface)
        }
    }

    private var dotConnector: some View {
        HStack(spacing: 0) {
            VStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(FlowTheme.outline)
                        .frame(width: 3, height: 3)
                }
            }
            .padding(.vertical, 2)
            Spacer()
        }
        .padding(.leading, 23)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(FlowTheme.error)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FlowTheme.error)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(FlowTheme.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var searchButton: some View {
        Button("Search Rides") {
            Task { await search() }
        }
        .buttonStyle(FlowPrimaryButtonStyle())
        .disabled(isBusy || !isValid)
        .opacity(isValid ? 1 : 0.5)
    }

    // MARK: - Results

    private func matchResultsSection(_ results: [MatchResult]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowSectionHeader(title: "\(results.count) ride\(results.count == 1 ? "" : "s") found", icon: "car.2")

            if results.isEmpty {
                FlowEmptyState(
                    icon: "magnifyingglass",
                    title: "No rides found",
                    subtitle: "Try a different date or adjust your route."
                )
            } else {
                ForEach(results) { match in
                    MatchRow(
                        match: match,
                        riderDepartureAddress: departureAddress,
                        riderArrivalAddress: arrivalAddress,
                        wantedArrivalAt: buildWantedArrivalISO()
                    )
                }
            }
        }
    }

    // MARK: - Logic

    private var isValid: Bool {
        !departureAddress.trimmingCharacters(in: .whitespaces).isEmpty
        && !arrivalAddress.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func buildWantedArrivalISO() -> String {
        let cal = Calendar.current
        let timeComps = cal.dateComponents([.hour, .minute], from: wantedArrivalTime)
        var dateComps = cal.dateComponents([.year, .month, .day], from: departureDate)
        dateComps.hour = timeComps.hour
        dateComps.minute = timeComps.minute
        dateComps.second = 0
        let combined = cal.date(from: dateComps) ?? Date()
        return FlowFormatters.iso8601String(from: combined)
    }

    private func search() async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        let req = MatchesRequest(
            departureDate: FlowFormatters.dateOnlyString(from: departureDate),
            riderDepartureAddress: departureAddress.trimmingCharacters(in: .whitespaces),
            riderArrivalAddress: arrivalAddress.trimmingCharacters(in: .whitespaces),
            wantedArrivalAt: buildWantedArrivalISO(),
            clientTimeZone: TimeZone.current.identifier
        )

        do {
            let resp = try await APIClient.shared.searchMatches(req)
            matches = resp.matches
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func defaultArrivalTime() -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 9
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    static func defaultSearchDate() -> Date {
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)
        if hour >= 10 {
            return cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now
        }
        return now
    }
}

// MARK: - Match Row

struct MatchRow: View {
    let match: MatchResult
    let riderDepartureAddress: String
    let riderArrivalAddress: String
    let wantedArrivalAt: String

    @State private var isApplying = false
    @State private var applied = false
    @State private var errorMessage: String?

    var body: some View {
        FlowCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(FlowTheme.primary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(match.driverDisplayName ?? "Driver")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(FlowTheme.onSurface)
                            Text("\(match.seatsRemaining) seat\(match.seatsRemaining == 1 ? "" : "s") left")
                                .font(.system(size: 13))
                                .foregroundStyle(FlowTheme.onSurfaceVariant)
                        }
                    }

                    Spacer()

                    scoreLabel
                }

                routeInfo

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FlowTheme.error)
                }

                applyButton
            }
        }
    }

    private var scoreLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 10))
            Text(String(format: "%.0f%%", match.score * 100))
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(FlowTheme.warning)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(FlowTheme.warning.opacity(0.12))
        .clipShape(Capsule())
    }

    private var routeInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            addressLabel(icon: "circle.fill", color: FlowTheme.primary, text: match.originAddress)
            addressLabel(icon: "mappin.circle.fill", color: FlowTheme.error, text: match.destinationAddress)
        }
    }

    private func addressLabel(icon: String, color: Color, text: String) -> some View {
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

    private var applyButton: some View {
        Group {
            if applied {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Applied!")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(FlowTheme.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(FlowTheme.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Button {
                    Task { await apply() }
                } label: {
                    HStack(spacing: 6) {
                        if isApplying {
                            ProgressView().tint(FlowTheme.onPrimary)
                        }
                        Text("Apply for Ride")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundStyle(FlowTheme.onPrimary)
                    .background(FlowTheme.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(isApplying)
            }
        }
    }

    private func apply() async {
        isApplying = true
        errorMessage = nil
        defer { isApplying = false }

        let req = ApplyRequest(
            riderDepartureAddress: riderDepartureAddress,
            riderArrivalAddress: riderArrivalAddress,
            wantedArrivalAt: wantedArrivalAt,
            clientTimeZone: TimeZone.current.identifier
        )

        do {
            let resp = try await APIClient.shared.applyToIntent(intentId: match.intentId, body: req)
            TripStore.shared.save(
                applicationId: resp.id,
                intentId: resp.intentId,
                departureDate: match.departureDate
            )
            applied = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
