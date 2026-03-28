import Contacts
import MapKit
import SwiftUI

// MARK: - Completer (wraps MKLocalSearchCompleter)

@Observable
final class AddressCompleter: NSObject, @preconcurrency MKLocalSearchCompleterDelegate {
    var completions: [MKLocalSearchCompletion] = []
    var isSearching = false

    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func update(query: String) {
        guard query.count >= 2 else {
            completions = []
            isSearching = false
            return
        }
        isSearching = true
        completer.queryFragment = query
    }

    func cancel() {
        completer.cancel()
        completions = []
        isSearching = false
    }

    func resolve(_ completion: MKLocalSearchCompletion) async -> String {
        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = .address
        let search = MKLocalSearch(request: request)

        if let response = try? await search.start(),
           let item = response.mapItems.first {
            return formattedAddress(from: item.placemark) ?? fallbackLabel(completion)
        }
        return fallbackLabel(completion)
    }

    // MARK: Delegate

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            self.completions = results
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.completions = []
            self.isSearching = false
        }
    }

    // MARK: Formatting

    private func formattedAddress(from placemark: MKPlacemark) -> String? {
        if let postal = placemark.postalAddress {
            let formatted = CNPostalAddressFormatter.string(from: postal, style: .mailingAddress)
            let oneLine = formatted
                .replacingOccurrences(of: "\n", with: ", ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !oneLine.isEmpty { return oneLine }
        }

        var parts: [String] = []
        if let subthoroughfare = placemark.subThoroughfare { parts.append(subthoroughfare) }
        if let thoroughfare = placemark.thoroughfare { parts.append(thoroughfare) }
        if let locality = placemark.locality { parts.append(locality) }
        if let adminArea = placemark.administrativeArea { parts.append(adminArea) }
        if let postalCode = placemark.postalCode { parts.append(postalCode) }
        if let country = placemark.country { parts.append(country) }
        let result = parts.joined(separator: ", ")
        return result.isEmpty ? nil : result
    }

    private func fallbackLabel(_ c: MKLocalSearchCompletion) -> String {
        c.subtitle.isEmpty ? c.title : "\(c.title), \(c.subtitle)"
    }
}

// MARK: - Reusable address field with autocomplete

struct AddressSearchField: View {
    let icon: String
    let iconColor: Color
    let placeholder: String
    @Binding var address: String

    @State private var completer = AddressCompleter()
    @State private var query = ""
    @State private var showSuggestions = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            fieldRow

            if showSuggestions && !completer.completions.isEmpty {
                suggestionsDropdown
            }
        }
    }

    // MARK: - Field

    private var fieldRow: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
                .frame(width: 20)

            TextField(placeholder, text: $query)
                .font(.system(size: 16))
                .foregroundStyle(FlowTheme.onSurface)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isFocused)
                .onChange(of: query) { _, newValue in
                    if newValue != address {
                        address = newValue
                        completer.update(query: newValue)
                        showSuggestions = true
                    }
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        Task {
                            try? await Task.sleep(for: .milliseconds(200))
                            showSuggestions = false
                        }
                    }
                }
                .onAppear {
                    query = address
                }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(FlowTheme.surfaceContainerHi)
        .clipShape(RoundedRectangle(cornerRadius: showSuggestions && !completer.completions.isEmpty ? 10 : 10, style: .continuous))
    }

    // MARK: - Suggestions

    private var suggestionsDropdown: some View {
        VStack(spacing: 0) {
            ForEach(Array(completer.completions.prefix(5).enumerated()), id: \.offset) { index, completion in
                Button {
                    select(completion)
                } label: {
                    suggestionRow(completion, isLast: index == min(completer.completions.count, 5) - 1)
                }
            }
        }
        .background(FlowTheme.surfaceContainerHi2)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .padding(.top, 2)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func suggestionRow(_ completion: MKLocalSearchCompletion, isLast: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 14))
                .foregroundStyle(FlowTheme.onSurfaceVariant.opacity(0.6))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(completion.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(FlowTheme.onSurface)
                    .lineLimit(1)
                if !completion.subtitle.isEmpty {
                    Text(completion.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(FlowTheme.onSurfaceVariant)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "arrow.up.left")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(FlowTheme.outline)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(FlowTheme.outline.opacity(0.15))
                    .frame(height: 0.5)
                    .padding(.leading, 44)
            }
        }
    }

    // MARK: - Selection

    private func select(_ completion: MKLocalSearchCompletion) {
        showSuggestions = false
        isFocused = false
        completer.cancel()

        let label = completion.subtitle.isEmpty ? completion.title : "\(completion.title), \(completion.subtitle)"
        query = label
        address = label

        Task {
            let resolved = await completer.resolve(completion)
            query = resolved
            address = resolved
        }
    }
}
