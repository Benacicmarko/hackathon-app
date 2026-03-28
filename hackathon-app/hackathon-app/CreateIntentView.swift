import SwiftUI

struct CreateIntentView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var departureDate = defaultDepartureDate()
    @State private var originAddress = ""
    @State private var destinationAddress = ""
    @State private var passengerSeats = 2
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var didCreate = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                VStack(spacing: 16) {
                    dateSection
                    addressSection
                    seatsSection
                }

                if let errorMessage {
                    errorBanner(errorMessage)
                }

                createButton

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(FlowTheme.surface)
        .navigationTitle("Offer a Ride")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Ride Created!", isPresented: $didCreate) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your commute is now open for riders.")
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "car.fill")
                .font(.system(size: 36))
                .foregroundStyle(FlowTheme.primary)
            Text("Share your commute")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(FlowTheme.onSurface)
            Text("Let others ride along on your way to work.")
                .font(.system(size: 15))
                .foregroundStyle(FlowTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    private var dateSection: some View {
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

    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowSectionHeader(title: "Route", icon: "map")
            VStack(spacing: 2) {
                AddressSearchField(
                    icon: "circle.fill",
                    iconColor: FlowTheme.primary,
                    placeholder: "Pickup address (your home)",
                    address: $originAddress
                )
                HStack(spacing: 0) {
                    dotLine
                    Spacer()
                }
                .padding(.leading, 23)
                AddressSearchField(
                    icon: "mappin.circle.fill",
                    iconColor: FlowTheme.error,
                    placeholder: "Destination (your work)",
                    address: $destinationAddress
                )
            }
        }
        .zIndex(1)
    }

    private var dotLine: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(FlowTheme.outline)
                    .frame(width: 3, height: 3)
            }
        }
        .padding(.vertical, 2)
    }

    private var seatsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowSectionHeader(title: "Passenger Seats", icon: "person.2")
            HStack {
                SeatIndicator(filled: 0, total: passengerSeats)

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        if passengerSeats > 1 { passengerSeats -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(passengerSeats > 1 ? FlowTheme.primary : FlowTheme.outline)
                    }
                    .disabled(passengerSeats <= 1)

                    Text("\(passengerSeats)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(FlowTheme.onSurface)
                        .frame(minWidth: 30)

                    Button {
                        if passengerSeats < 8 { passengerSeats += 1 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(passengerSeats < 8 ? FlowTheme.primary : FlowTheme.outline)
                    }
                    .disabled(passengerSeats >= 8)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(FlowTheme.surfaceContainerHi)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
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

    private var createButton: some View {
        Button("Create Ride") {
            Task { await createIntent() }
        }
        .buttonStyle(FlowPrimaryButtonStyle())
        .disabled(isBusy || !isValid)
        .opacity(isValid ? 1 : 0.5)
    }

    // MARK: - Validation & submission

    private var isValid: Bool {
        !originAddress.trimmingCharacters(in: .whitespaces).isEmpty
        && !destinationAddress.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func createIntent() async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        let req = CreateIntentRequest(
            departureDate: FlowFormatters.dateOnlyString(from: departureDate),
            originAddress: originAddress.trimmingCharacters(in: .whitespaces),
            destinationAddress: destinationAddress.trimmingCharacters(in: .whitespaces),
            passengerSeats: passengerSeats,
            clientTimeZone: TimeZone.current.identifier
        )

        do {
            _ = try await APIClient.shared.createIntent(req)
            didCreate = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func defaultDepartureDate() -> Date {
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)
        if hour >= 10 {
            return cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now
        }
        return now
    }
}
